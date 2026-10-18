/* Exact hybrid retrieval. ACL is applied before ranking and once more by the caller. */
CREATE OR ALTER PROCEDURE assistant.usp_SearchRag
    @UserID bigint,
    @Question nvarchar(2000),
    @QueryEmbedding nvarchar(max), -- JSON array supplied by the embedding client
    @TopK int = 5,
    @QueryEntitiesJson nvarchar(max) = N'[]',
    @CommunityID bigint = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @TopK IS NULL OR @TopK NOT BETWEEN 1 AND 20
       OR NULLIF(LTRIM(RTRIM(@Question)), N'') IS NULL
        THROW 51020, N'Question or TopK is invalid.', 1;
    IF NOT EXISTS
       (SELECT 1 FROM auth.UserAccount
        WHERE UserID=@UserID AND AccountStatus='ACTIVE')
        THROW 51033, N'Active user is required.', 1;
    IF @QueryEmbedding IS NULL OR @QueryEntitiesJson IS NULL
       OR ISJSON(@QueryEmbedding, ARRAY) <> 1
       OR ISJSON(@QueryEntitiesJson, ARRAY) <> 1
        THROW 51021, N'Embedding and entities must be JSON arrays.', 1;
    IF (SELECT COUNT(*) FROM OPENJSON(@QueryEmbedding)) <> 384
       OR EXISTS (SELECT 1 FROM OPENJSON(@QueryEmbedding)
                  WHERE [type] <> 2 OR TRY_CONVERT(float,[value]) IS NULL)
       OR NOT EXISTS (SELECT 1 FROM OPENJSON(@QueryEmbedding)
                      WHERE TRY_CONVERT(float,[value]) <> 0)
        THROW 51026, N'Embedding must contain 384 numeric values and be nonzero.', 1;
    IF @CommunityID IS NOT NULL AND NOT EXISTS
       (SELECT 1 FROM auth.fn_UserCanReadCommunity(@UserID,@CommunityID))
        THROW 51027, N'Community is not accessible to this user.', 1;

    DECLARE @Vector vector(384) = CAST(@QueryEmbedding AS vector(384));

    ;WITH QueryNames AS
    (
        SELECT DISTINCT CAST([value] AS nvarchar(500)) AS EntityName
        FROM OPENJSON(@QueryEntitiesJson)
        WHERE [type] = 1 AND LEN([value]) BETWEEN 2 AND 500
    ),
    DirectGraph AS
    (
        SELECT mention.EvidenceChunkID AS ChunkID,
               CAST(MAX(mention.Confidence) AS float) AS Score
        FROM knowledge.Chunk AS chunk,
             knowledge.Mentions AS mention,
             knowledge.KnowledgeEntity AS entity
        WHERE MATCH(chunk-(mention)->entity)
          AND mention.EvidenceChunkID = chunk.ChunkID
          AND EXISTS (SELECT 1 FROM QueryNames AS q WHERE q.EntityName = entity.EntityName)
        GROUP BY mention.EvidenceChunkID
    ),
    RelatedGraph AS
    (
        SELECT mention.EvidenceChunkID AS ChunkID,
               CAST(MAX(0.5 * relation.Confidence * mention.Confidence) AS float) AS Score
        FROM knowledge.KnowledgeEntity AS queryEntity,
             knowledge.EntityRelation AS relation,
             knowledge.KnowledgeEntity AS relatedEntity,
             knowledge.Chunk AS chunk,
             knowledge.Mentions AS mention,
             knowledge.vCurrentRagChunks AS evidence,
             social.vAccessibleContent AS evidenceAccess
        WHERE MATCH(queryEntity-(relation)->relatedEntity)
          AND MATCH(chunk-(mention)->relatedEntity)
          AND mention.EvidenceChunkID = chunk.ChunkID
          AND evidence.ChunkID = relation.EvidenceChunkID
          AND evidenceAccess.UserID = @UserID
          AND evidenceAccess.ContentID = evidence.ContentID
          AND (@CommunityID IS NULL OR evidenceAccess.CommunityID = @CommunityID)
          AND EXISTS (SELECT 1 FROM QueryNames AS q WHERE q.EntityName = queryEntity.EntityName)
        GROUP BY mention.EvidenceChunkID
    ),
    GraphScore AS
    (
        SELECT ChunkID, MAX(Score) AS Score
        FROM (SELECT * FROM DirectGraph UNION ALL SELECT * FROM RelatedGraph) AS evidence
        GROUP BY ChunkID
    ),
    Allowed AS
    (
        SELECT rag.ChunkID, rag.ContentID, rag.Kind, rag.ChunkText, rag.PageNo,
               rag.StartOffset, rag.EndOffset,
               rag.Title, access.AuthorUserID, access.CommunityID,
               CAST(1.0 - VECTOR_DISTANCE('cosine', embedding.Embedding, @Vector) AS float) AS VectorScore,
               /* SQL Server can return a matching key with RANK = 0 for a
                  natural-language question containing Russian noise words. */
               CAST(CASE WHEN fulltext.[KEY] IS NULL THEN 0.0
                         ELSE (fulltext.[RANK] + 1) / 1001.0 END AS float) AS TextScore,
               CAST(COALESCE(graph.Score, 0) AS float) AS GraphScore
        FROM knowledge.vCurrentRagChunks AS rag
        JOIN social.vAccessibleContent AS access
          ON access.UserID = @UserID AND access.ContentID = rag.ContentID
         AND (@CommunityID IS NULL OR access.CommunityID = @CommunityID)
        JOIN knowledge.ChunkEmbedding AS embedding
          ON embedding.ChunkID = rag.ChunkID
        JOIN knowledge.EmbeddingModel AS model
          ON model.ModelID = embedding.ModelID AND model.IsActive = 1
         AND model.ModelName = N'intfloat/multilingual-e5-small'
         AND model.ModelVersion = N'fd1525a9fd15316a2d503bf26ab031a61d056e98'
         AND model.Dimensions = 384
        LEFT JOIN FREETEXTTABLE(knowledge.Chunk, ChunkText, @Question) AS fulltext
          ON fulltext.[KEY] = rag.ChunkID
        LEFT JOIN GraphScore AS graph ON graph.ChunkID = rag.ChunkID
    ),
    Ranked AS
    (
        SELECT *, ROW_NUMBER() OVER
        (
            ORDER BY (0.55 * VectorScore + 0.30 * TextScore + 0.15 * GraphScore) DESC,
                     ChunkID
        ) AS [Rank]
        FROM Allowed
    )
    SELECT ChunkID, ContentID, Kind, ChunkText, PageNo, StartOffset, EndOffset, Title,
           AuthorUserID, CommunityID, [Rank], VectorScore, TextScore, GraphScore
    FROM Ranked
    WHERE [Rank] <= @TopK
      AND EXISTS
      (
          SELECT 1 FROM knowledge.vCurrentRagChunks AS currentChunk
          JOIN social.vAccessibleContent AS currentAccess
            ON currentAccess.UserID = @UserID
           AND currentAccess.ContentID = currentChunk.ContentID
          WHERE currentChunk.ChunkID = Ranked.ChunkID
      )
    ORDER BY [Rank];
END;
GO

/* The citation FK points to the exact retrieved set, and live ACL is checked again. */
CREATE OR ALTER PROCEDURE assistant.usp_SaveRagAnswer
    @TurnID bigint,
    @RetrievalRunID bigint,
    @AnswerText nvarchar(max),
    @AnswerModel nvarchar(120),
    @CitationsJson nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CitationsJson IS NULL OR ISJSON(@CitationsJson, ARRAY) <> 1
       OR NOT EXISTS (SELECT 1 FROM OPENJSON(@CitationsJson))
        THROW 51022, N'Completed answers require a nonempty citation array.', 1;
    IF NULLIF(LTRIM(RTRIM(@AnswerText)),N'') IS NULL
       OR NULLIF(LTRIM(RTRIM(@AnswerModel)),N'') IS NULL
        THROW 51028, N'Answer text and model are required.', 1;

    DECLARE @UserID bigint;
    SELECT @UserID = session.UserID
    FROM assistant.RagTurn AS turn
    JOIN assistant.RagSession AS session ON session.SessionID = turn.SessionID
    JOIN assistant.RetrievalRun AS run ON run.TurnID = turn.TurnID
    WHERE turn.TurnID = @TurnID AND run.RetrievalRunID = @RetrievalRunID;
    IF @UserID IS NULL THROW 51023, N'Turn or retrieval run not found.', 1;

    DECLARE @Citation TABLE
    (
        ChunkID bigint NOT NULL PRIMARY KEY,
        QuoteText nvarchar(1000) NOT NULL,
        PageNo int NULL,
        StartOffset int NOT NULL,
        EndOffset int NOT NULL
    );
    INSERT INTO @Citation (ChunkID, QuoteText, PageNo, StartOffset, EndOffset)
    SELECT chunk_id, quote, page_no, start_offset, end_offset
    FROM OPENJSON(@CitationsJson)
    WITH
    (
        chunk_id bigint '$.chunk_id',
        quote nvarchar(1000) '$.quote',
        page_no int '$.page_no',
        start_offset int '$.start_offset',
        end_offset int '$.end_offset'
    );

    BEGIN TRY
        BEGIN TRANSACTION;
        IF EXISTS
        (
            SELECT 1
            FROM assistant.RetrievedChunk AS usedChunk
            LEFT JOIN knowledge.vCurrentRagChunks AS currentChunk
              ON currentChunk.ChunkID = usedChunk.ChunkID
            LEFT JOIN social.vAccessibleContent AS access
              ON access.UserID = @UserID AND access.ContentID = currentChunk.ContentID
            WHERE usedChunk.RetrievalRunID = @RetrievalRunID
              AND access.ContentID IS NULL
        ) THROW 51025, N'A retrieved source is no longer accessible.', 1;
        IF EXISTS
        (
            SELECT 1 FROM @Citation AS citation
            LEFT JOIN assistant.RetrievedChunk AS retrieved
              ON retrieved.RetrievalRunID = @RetrievalRunID
             AND retrieved.ChunkID = citation.ChunkID
            LEFT JOIN knowledge.vCurrentRagChunks AS currentChunk
              ON currentChunk.ChunkID = citation.ChunkID
            LEFT JOIN social.vAccessibleContent AS access
              ON access.UserID = @UserID AND access.ContentID = currentChunk.ContentID
            WHERE retrieved.ChunkID IS NULL OR access.ContentID IS NULL
               OR citation.StartOffset < currentChunk.StartOffset
               OR citation.EndOffset > currentChunk.EndOffset
               OR citation.EndOffset <= citation.StartOffset
               OR NULLIF(citation.QuoteText, N'') IS NULL
               OR citation.PageNo <> currentChunk.PageNo
               OR (citation.PageNo IS NULL AND currentChunk.PageNo IS NOT NULL)
               OR (citation.PageNo IS NOT NULL AND currentChunk.PageNo IS NULL)
               OR CONVERT(varbinary(max),SUBSTRING(
                      currentChunk.ChunkText,
                      citation.StartOffset-currentChunk.StartOffset+1,
                      citation.EndOffset-citation.StartOffset))
                  <> CONVERT(varbinary(max),citation.QuoteText)
        ) THROW 51024, N'Citation is not an accessible, retrieved source.', 1;

        DELETE FROM assistant.AnswerCitation
        WHERE RetrievalRunID = @RetrievalRunID;
        INSERT INTO assistant.AnswerCitation
            (RetrievalRunID, ChunkID, QuoteText, PageNo, StartOffset, EndOffset)
        SELECT @RetrievalRunID, ChunkID, QuoteText, PageNo, StartOffset, EndOffset
        FROM @Citation;
        UPDATE assistant.RagTurn
        SET AnswerText = @AnswerText, AnswerModel = @AnswerModel,
            GenerationStatus = 'COMPLETED', CompletedAt = SYSUTCDATETIME()
        WHERE TurnID = @TurnID AND GenerationStatus = 'PENDING';
        IF @@ROWCOUNT <> 1 THROW 51029, N'Turn is already finished.', 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* An empty retrieval is recorded explicitly without asking an LLM to guess. */
CREATE OR ALTER PROCEDURE assistant.usp_SaveRagNoSources
    @TurnID bigint,
    @RetrievalRunID bigint
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS
           (SELECT 1 FROM assistant.RetrievalRun
            WHERE RetrievalRunID=@RetrievalRunID AND TurnID=@TurnID)
            THROW 51040, N'Retrieval run does not belong to this turn.', 1;
        IF EXISTS
           (SELECT 1 FROM assistant.RetrievedChunk
            WHERE RetrievalRunID=@RetrievalRunID)
            THROW 51041, N'This retrieval run already has sources.', 1;
        UPDATE assistant.RagTurn
        SET AnswerText=N'Недостаточно доступных источников для ответа.',
            AnswerModel=NULL,GenerationStatus='NO_SOURCES',
            CompletedAt=SYSUTCDATETIME()
        WHERE TurnID=@TurnID AND GenerationStatus='PENDING';
        IF @@ROWCOUNT<>1 THROW 51042, N'Turn is already finished.', 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
