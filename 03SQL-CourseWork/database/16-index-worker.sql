/* Workers use claim-bound procedures; they never write index tables directly. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE ops.usp_GetClaimedIndexSource
    @EventID bigint,
    @ClaimToken uniqueidentifier
AS
BEGIN
    SET NOCOUNT ON;
    SELECT event.EventID, event.SourceRevisionID, event.ModelID,
           event.Operation, source.ContentID, item.Kind,
           source.IsCurrent, item.ContentStatus, item.AllowRag,
           source.ExtractedText, version.DocumentVersionID,
           version.MimeType, version.FileName, version.FileBytes,
           version.PlainText, model.ModelName, model.ModelVersion,
           model.Dimensions
    FROM ops.IndexOutbox AS event
    JOIN knowledge.SourceRevision AS source
      ON source.SourceRevisionID = event.SourceRevisionID
    JOIN social.ContentItem AS item ON item.ContentID = source.ContentID
    LEFT JOIN knowledge.DocumentVersion AS version
      ON version.DocumentVersionID = source.DocumentVersionID
    LEFT JOIN knowledge.EmbeddingModel AS model
      ON model.ModelID = event.ModelID
    WHERE event.EventID = @EventID
      AND event.ClaimToken = @ClaimToken
      AND event.EventStatus = 'CLAIMED'
      AND event.LeaseUntil > SYSUTCDATETIME();
    IF @@ROWCOUNT <> 1
        THROW 51080, N'Index claim is missing or expired.', 1;
END;
GO

/* Reclaim only after the old worker can no longer commit with its token. */
CREATE OR ALTER PROCEDURE ops.usp_RequeueExpiredIndexOutbox
    @BatchSize int = 10
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @BatchSize IS NULL OR @BatchSize NOT BETWEEN 1 AND 100
        THROW 51088, N'Invalid requeue batch size.', 1;
    DECLARE @Expired TABLE
    (EventID bigint PRIMARY KEY,SourceRevisionID bigint,EventStatus varchar(8));
    BEGIN TRY
        BEGIN TRANSACTION;
        ;WITH expired AS
        (
            SELECT TOP (@BatchSize) *
            FROM ops.IndexOutbox WITH (READPAST,UPDLOCK,ROWLOCK)
            WHERE EventStatus = 'CLAIMED' AND LeaseUntil < SYSUTCDATETIME()
            ORDER BY LeaseUntil,EventID
        )
        UPDATE expired
        SET EventStatus=CASE WHEN AttemptCount >= 3 THEN 'FAILED' ELSE 'PENDING' END,
            ClaimedAt=NULL,LeaseUntil=NULL,ClaimToken=NULL,
            LastError=N'Worker lease expired.'
        OUTPUT inserted.EventID,inserted.SourceRevisionID,inserted.EventStatus
        INTO @Expired(EventID,SourceRevisionID,EventStatus);

        UPDATE source SET ProcessingStatus='FAILED',ProcessedAt=SYSUTCDATETIME()
        FROM knowledge.SourceRevision AS source
        JOIN @Expired AS event ON event.SourceRevisionID=source.SourceRevisionID
        WHERE event.EventStatus='FAILED' AND source.IsCurrent=1;
        UPDATE detail SET DocumentStatus='FAILED'
        FROM social.DocumentDetail AS detail
        JOIN knowledge.SourceRevision AS source ON source.ContentID=detail.ContentID
        JOIN @Expired AS event ON event.SourceRevisionID=source.SourceRevisionID
        WHERE event.EventStatus='FAILED' AND source.IsCurrent=1;
        UPDATE version SET OCRStatus='FAILED'
        FROM knowledge.DocumentVersion AS version
        JOIN knowledge.SourceRevision AS source
          ON source.DocumentVersionID=version.DocumentVersionID
        JOIN @Expired AS event ON event.SourceRevisionID=source.SourceRevisionID
        WHERE event.EventStatus='FAILED' AND source.IsCurrent=1
          AND version.OCRStatus='PENDING';
        COMMIT TRANSACTION;
        SELECT EventID,EventStatus FROM @Expired ORDER BY EventID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE ops.usp_RenewIndexLease
    @EventID bigint,
    @ClaimToken uniqueidentifier
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE ops.IndexOutbox
    SET LeaseUntil=DATEADD(minute,10,SYSUTCDATETIME())
    WHERE EventID=@EventID AND ClaimToken=@ClaimToken
      AND EventStatus='CLAIMED' AND LeaseUntil>SYSUTCDATETIME();
    IF @@ROWCOUNT<>1
        THROW 51089, N'Index claim is missing or expired.', 1;
END;
GO

/*
 * JSON contracts:
 * chunks: [{chunk_no,text,page_no,start_offset,end_offset,embedding:[384 floats]}]
 * mentions: [{local_id,entity_type,entity_name,chunk_no,start_offset,
 *             end_offset,evidence_text,confidence,extractor_version}]
 * relations: [{from_local_id,to_local_id,predicate_code,chunk_no,
 *              start_offset,end_offset,evidence_text,confidence,extractor_version}]
 * Offsets are zero-based positions under this database's LEN/SUBSTRING collation
 * semantics. The worker must use the same counting rule for supplementary text.
 */
CREATE OR ALTER PROCEDURE ops.usp_CommitIndexResult
    @EventID bigint,
    @ClaimToken uniqueidentifier,
    @ExtractedText nvarchar(max),
    @ChunksJson nvarchar(max),
    @MentionsJson nvarchar(max) = N'[]',
    @RelationsJson nvarchar(max) = N'[]',
    @OcrEngineVersion nvarchar(80) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @ClaimToken IS NULL OR @EventID IS NULL
       OR NULLIF(LTRIM(RTRIM(@ExtractedText)), N'') IS NULL
       OR ISNULL(ISJSON(@ChunksJson, ARRAY),0) <> 1
       OR ISNULL(ISJSON(@MentionsJson, ARRAY),0) <> 1
       OR ISNULL(ISJSON(@RelationsJson, ARRAY),0) <> 1
       OR NOT EXISTS (SELECT 1 FROM OPENJSON(@ChunksJson))
        THROW 51081, N'Index payload is missing or malformed.', 1;

    DECLARE @Chunks TABLE
    (
        ChunkNo int NOT NULL PRIMARY KEY,
        ChunkText nvarchar(max) NOT NULL,
        PageNo int NULL,
        StartOffset int NOT NULL,
        EndOffset int NOT NULL,
        EmbeddingJson nvarchar(max) NOT NULL
    );
    INSERT INTO @Chunks
        (ChunkNo,ChunkText,PageNo,StartOffset,EndOffset,EmbeddingJson)
    SELECT chunk_no,[text],page_no,start_offset,end_offset,embedding
    FROM OPENJSON(@ChunksJson)
    WITH
    (
        chunk_no int '$.chunk_no',
        [text] nvarchar(max) '$.text',
        page_no int '$.page_no',
        start_offset int '$.start_offset',
        end_offset int '$.end_offset',
        embedding nvarchar(max) '$.embedding' AS JSON
    );
    IF (SELECT COUNT(*) FROM @Chunks) <> (SELECT COUNT(*) FROM OPENJSON(@ChunksJson))
       OR EXISTS
       (
           SELECT 1 FROM @Chunks
           WHERE ChunkNo < 1 OR StartOffset < 0 OR EndOffset <= StartOffset
              OR EndOffset > DATALENGTH(@ExtractedText)/2
              OR (PageNo IS NOT NULL AND PageNo < 1)
              OR DATALENGTH(ChunkText) = 0
              OR CONVERT(varbinary(max), SUBSTRING(@ExtractedText,StartOffset+1,EndOffset-StartOffset))
                 <> CONVERT(varbinary(max),ChunkText)
              OR ISJSON(EmbeddingJson, ARRAY) <> 1
              OR (SELECT COUNT(*) FROM OPENJSON(EmbeddingJson)) <> 384
              OR EXISTS (SELECT 1 FROM OPENJSON(EmbeddingJson)
                         WHERE [type] <> 2 OR TRY_CONVERT(float,[value]) IS NULL)
              OR NOT EXISTS (SELECT 1 FROM OPENJSON(EmbeddingJson)
                             WHERE TRY_CONVERT(float,[value]) <> 0)
       )
        THROW 51082, N'Chunk offsets, text, or 384D embedding is invalid.', 1;

    DECLARE @Mentions TABLE
    (
        LocalID int NOT NULL PRIMARY KEY,
        EntityType varchar(14) NOT NULL,
        EntityName nvarchar(500) NOT NULL,
        ChunkNo int NOT NULL,
        StartOffset int NOT NULL,
        EndOffset int NOT NULL,
        EvidenceText nvarchar(1000) NOT NULL,
        Confidence decimal(4,3) NOT NULL,
        ExtractorVersion nvarchar(80) NOT NULL
    );
    INSERT INTO @Mentions
        (LocalID,EntityType,EntityName,ChunkNo,StartOffset,EndOffset,
         EvidenceText,Confidence,ExtractorVersion)
    SELECT local_id,entity_type,entity_name,chunk_no,start_offset,end_offset,
           evidence_text,confidence,extractor_version
    FROM OPENJSON(@MentionsJson)
    WITH
    (
        local_id int '$.local_id', entity_type varchar(14) '$.entity_type',
        entity_name nvarchar(500) '$.entity_name', chunk_no int '$.chunk_no',
        start_offset int '$.start_offset', end_offset int '$.end_offset',
        evidence_text nvarchar(1000) '$.evidence_text',
        confidence decimal(4,3) '$.confidence',
        extractor_version nvarchar(80) '$.extractor_version'
    );
    IF EXISTS
       (
           SELECT 1 FROM @Mentions AS mention
           LEFT JOIN @Chunks AS chunk ON chunk.ChunkNo = mention.ChunkNo
           WHERE mention.LocalID < 1 OR chunk.ChunkNo IS NULL
              OR mention.EntityType NOT IN ('TOPIC','PERSON','ORGANIZATION','EVENT','PLACE')
              OR NULLIF(LTRIM(RTRIM(mention.EntityName)),N'') IS NULL
              OR NULLIF(mention.ExtractorVersion,N'') IS NULL
              OR mention.Confidence NOT BETWEEN 0 AND 1
              OR mention.StartOffset < chunk.StartOffset
              OR mention.EndOffset > chunk.EndOffset
              OR mention.EndOffset <= mention.StartOffset
              OR CONVERT(varbinary(max),SUBSTRING(@ExtractedText,
                    mention.StartOffset+1,mention.EndOffset-mention.StartOffset))
                 <> CONVERT(varbinary(max),mention.EvidenceText)
       )
        THROW 51083, N'Entity mention has invalid evidence.', 1;

    DECLARE @Relations TABLE
    (
        FromLocalID int NOT NULL,
        ToLocalID int NOT NULL,
        PredicateCode varchar(20) NOT NULL,
        ChunkNo int NOT NULL,
        StartOffset int NOT NULL,
        EndOffset int NOT NULL,
        EvidenceText nvarchar(1000) NOT NULL,
        Confidence decimal(4,3) NOT NULL,
        ExtractorVersion nvarchar(80) NOT NULL
    );
    INSERT INTO @Relations
        (FromLocalID,ToLocalID,PredicateCode,ChunkNo,StartOffset,EndOffset,
         EvidenceText,Confidence,ExtractorVersion)
    SELECT from_local_id,to_local_id,predicate_code,chunk_no,start_offset,end_offset,
           evidence_text,confidence,extractor_version
    FROM OPENJSON(@RelationsJson)
    WITH
    (
        from_local_id int '$.from_local_id', to_local_id int '$.to_local_id',
        predicate_code varchar(20) '$.predicate_code', chunk_no int '$.chunk_no',
        start_offset int '$.start_offset', end_offset int '$.end_offset',
        evidence_text nvarchar(1000) '$.evidence_text',
        confidence decimal(4,3) '$.confidence',
        extractor_version nvarchar(80) '$.extractor_version'
    );
    IF EXISTS
       (
           SELECT 1 FROM @Relations AS relation
           LEFT JOIN @Chunks AS chunk ON chunk.ChunkNo = relation.ChunkNo
           LEFT JOIN @Mentions AS origin ON origin.LocalID = relation.FromLocalID
           LEFT JOIN @Mentions AS target ON target.LocalID = relation.ToLocalID
           WHERE chunk.ChunkNo IS NULL OR origin.LocalID IS NULL OR target.LocalID IS NULL
              OR origin.ChunkNo <> relation.ChunkNo
              OR target.ChunkNo <> relation.ChunkNo
              OR relation.StartOffset > origin.StartOffset
              OR relation.EndOffset < origin.EndOffset
              OR relation.StartOffset > target.StartOffset
              OR relation.EndOffset < target.EndOffset
              OR relation.PredicateCode NOT IN
                 ('PARTICIPATES_IN','WORKS_AT','TAKES_PLACE_IN','RELATED_TO')
              OR NULLIF(relation.ExtractorVersion,N'') IS NULL
              OR relation.Confidence NOT BETWEEN 0 AND 1
              OR relation.StartOffset < chunk.StartOffset
              OR relation.EndOffset > chunk.EndOffset
              OR relation.EndOffset <= relation.StartOffset
              OR CONVERT(varbinary(max),SUBSTRING(@ExtractedText,
                    relation.StartOffset+1,relation.EndOffset-relation.StartOffset))
                 <> CONVERT(varbinary(max),relation.EvidenceText)
       )
        THROW 51084, N'Entity relation has invalid evidence.', 1;

    DECLARE @SourceRevisionID bigint, @ContentID bigint, @ModelID int,
            @DocumentVersionID bigint;
    DECLARE @ChunkMap TABLE (ChunkNo int PRIMARY KEY, ChunkID bigint NOT NULL);
    DECLARE @EntityMap TABLE (LocalID int PRIMARY KEY, EntityID bigint NOT NULL);

    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT @SourceRevisionID = event.SourceRevisionID,
               @ModelID = event.ModelID,
               @ContentID = source.ContentID,
               @DocumentVersionID = source.DocumentVersionID
        FROM ops.IndexOutbox AS event WITH (UPDLOCK,HOLDLOCK)
        JOIN knowledge.SourceRevision AS source WITH (UPDLOCK,HOLDLOCK)
          ON source.SourceRevisionID = event.SourceRevisionID
        JOIN social.ContentItem AS item WITH (UPDLOCK,HOLDLOCK)
          ON item.ContentID = source.ContentID
        WHERE event.EventID = @EventID AND event.ClaimToken = @ClaimToken
          AND event.EventStatus = 'CLAIMED'
          AND event.LeaseUntil > SYSUTCDATETIME()
          AND event.Operation = 'UPSERT'
          AND source.IsCurrent = 1
          AND item.ContentStatus = 'PUBLISHED'
          AND item.AllowRag = 1;
        IF @SourceRevisionID IS NULL OR @ModelID IS NULL
            THROW 51085, N'Index claim is stale or source is no longer publishable.', 1;

        EXEC ops.usp_ResetSourceIndex @SourceRevisionID = @SourceRevisionID;
        UPDATE knowledge.SourceRevision
        SET ExtractedText = @ExtractedText,
            TextHash = HASHBYTES('SHA2_256',CONVERT(varbinary(max),@ExtractedText)),
            ProcessingStatus = 'PENDING', ProcessedAt = NULL
        WHERE SourceRevisionID = @SourceRevisionID;

        INSERT INTO knowledge.Chunk
            (SourceRevisionID,ChunkNo,ChunkText,PageNo,StartOffset,EndOffset,ChunkHash)
        OUTPUT inserted.ChunkNo,inserted.ChunkID INTO @ChunkMap(ChunkNo,ChunkID)
        SELECT @SourceRevisionID,ChunkNo,ChunkText,PageNo,StartOffset,EndOffset,
               HASHBYTES('SHA2_256',CONVERT(varbinary(max),ChunkText))
        FROM @Chunks;

        INSERT INTO knowledge.ChunkEmbedding (ChunkID,ModelID,Embedding)
        SELECT map.ChunkID,@ModelID,CAST(chunk.EmbeddingJson AS vector(384))
        FROM @Chunks AS chunk JOIN @ChunkMap AS map ON map.ChunkNo=chunk.ChunkNo;

        INSERT INTO knowledge.ChunkOf ($from_id,$to_id)
        SELECT chunk.$node_id,item.$node_id
        FROM knowledge.Chunk AS chunk
        JOIN @ChunkMap AS map ON map.ChunkID=chunk.ChunkID
        CROSS JOIN social.ContentItem AS item
        WHERE item.ContentID=@ContentID;

        DECLARE @LocalID int, @EntityID bigint, @EntityType varchar(14),
                @EntityName nvarchar(500), @ExtractorVersion nvarchar(80);
        DECLARE mention_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT LocalID,EntityType,EntityName,ExtractorVersion FROM @Mentions ORDER BY LocalID;
        OPEN mention_cursor;
        FETCH NEXT FROM mention_cursor
            INTO @LocalID,@EntityType,@EntityName,@ExtractorVersion;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            INSERT INTO knowledge.KnowledgeEntity(EntityType,EntityName,ExtractorVersion)
            VALUES (@EntityType,@EntityName,@ExtractorVersion);
            SET @EntityID = CONVERT(bigint,SCOPE_IDENTITY());
            INSERT INTO @EntityMap(LocalID,EntityID) VALUES (@LocalID,@EntityID);
            FETCH NEXT FROM mention_cursor
                INTO @LocalID,@EntityType,@EntityName,@ExtractorVersion;
        END;
        CLOSE mention_cursor;
        DEALLOCATE mention_cursor;

        INSERT INTO knowledge.Mentions
            ($from_id,$to_id,EvidenceChunkID,StartOffset,EndOffset,
             EvidenceText,Confidence,ExtractorVersion)
        SELECT chunk.$node_id,entity.$node_id,map.ChunkID,
               mention.StartOffset,mention.EndOffset,mention.EvidenceText,
               mention.Confidence,mention.ExtractorVersion
        FROM @Mentions AS mention
        JOIN @ChunkMap AS map ON map.ChunkNo=mention.ChunkNo
        JOIN knowledge.Chunk AS chunk ON chunk.ChunkID=map.ChunkID
        JOIN @EntityMap AS entityMap ON entityMap.LocalID=mention.LocalID
        JOIN knowledge.KnowledgeEntity AS entity ON entity.EntityID=entityMap.EntityID;

        INSERT INTO knowledge.EntityRelation
            ($from_id,$to_id,PredicateCode,EvidenceChunkID,StartOffset,EndOffset,
             EvidenceText,Confidence,ExtractorVersion)
        SELECT origin.$node_id,target.$node_id,relation.PredicateCode,map.ChunkID,
               relation.StartOffset,relation.EndOffset,relation.EvidenceText,
               relation.Confidence,relation.ExtractorVersion
        FROM @Relations AS relation
        JOIN @ChunkMap AS map ON map.ChunkNo=relation.ChunkNo
        JOIN @EntityMap AS originMap ON originMap.LocalID=relation.FromLocalID
        JOIN @EntityMap AS targetMap ON targetMap.LocalID=relation.ToLocalID
        JOIN knowledge.KnowledgeEntity AS origin ON origin.EntityID=originMap.EntityID
        JOIN knowledge.KnowledgeEntity AS target ON target.EntityID=targetMap.EntityID;

        UPDATE knowledge.SourceRevision
        SET ProcessingStatus='READY',ProcessedAt=SYSUTCDATETIME()
        WHERE SourceRevisionID=@SourceRevisionID;
        IF @DocumentVersionID IS NOT NULL
        BEGIN
            UPDATE knowledge.DocumentVersion
            SET OCRStatus=CASE WHEN MimeType='application/pdf'
                               THEN 'COMPLETED' ELSE 'NOT_NEEDED' END,
                OcrEngineVersion=@OcrEngineVersion
            WHERE DocumentVersionID=@DocumentVersionID;
            UPDATE social.DocumentDetail SET DocumentStatus='READY'
            WHERE ContentID=@ContentID;
        END;
        UPDATE ops.IndexOutbox
        SET EventStatus='DONE',ProcessedAt=SYSUTCDATETIME(),
            ClaimToken=NULL,LeaseUntil=NULL,LastError=NULL
        WHERE EventID=@EventID AND ClaimToken=@ClaimToken;
        IF @@ROWCOUNT <> 1 THROW 51086, N'Index claim expired during commit.', 1;
        COMMIT TRANSACTION;
        SELECT @SourceRevisionID AS SourceRevisionID,
               (SELECT COUNT(*) FROM @ChunkMap) AS ChunkCount,
               (SELECT COUNT(*) FROM @EntityMap) AS EntityCount;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','mention_cursor') >= 0 CLOSE mention_cursor;
        IF CURSOR_STATUS('local','mention_cursor') > -3 DEALLOCATE mention_cursor;
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE ops.usp_CommitIndexDeletion
    @EventID bigint,
    @ClaimToken uniqueidentifier
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @SourceRevisionID bigint;
    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT @SourceRevisionID=SourceRevisionID
        FROM ops.IndexOutbox WITH (UPDLOCK,HOLDLOCK)
        WHERE EventID=@EventID AND ClaimToken=@ClaimToken
          AND EventStatus='CLAIMED' AND Operation='DELETE'
          AND LeaseUntil>SYSUTCDATETIME();
        IF @SourceRevisionID IS NULL
            THROW 51087, N'Deletion claim is missing or expired.', 1;
        EXEC ops.usp_ResetSourceIndex @SourceRevisionID=@SourceRevisionID;
        UPDATE ops.IndexOutbox
        SET EventStatus='DONE',ProcessedAt=SYSUTCDATETIME(),
            ClaimToken=NULL,LeaseUntil=NULL,LastError=NULL
        WHERE EventID=@EventID AND ClaimToken=@ClaimToken;
        IF @@ROWCOUNT<>1 THROW 51087, N'Deletion claim expired.', 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
