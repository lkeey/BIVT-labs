/* Source insertions enqueue one indexing event per active embedding model. */
CREATE OR ALTER TRIGGER knowledge.trg_SourceRevision_Enqueue
ON knowledge.SourceRevision
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO ops.IndexOutbox (SourceRevisionID, ModelID, Operation)
    SELECT inserted.SourceRevisionID, model.ModelID, 'UPSERT'
    FROM inserted
    CROSS JOIN knowledge.EmbeddingModel AS model
    WHERE model.IsActive = 1;
END;
GO

/* Edge constraints cover node table types; this trigger covers self-follow semantics. */
CREATE OR ALTER TRIGGER social.trg_Follows_NoSelf
ON social.Follows
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM social.Follows WHERE $from_id=$to_id)
        THROW 51017, N'A user cannot follow themself.', 1;
END;
GO

/* READPAST + a lease lets multiple workers safely claim independent events. */
CREATE OR ALTER PROCEDURE ops.usp_ClaimIndexOutbox
    @BatchSize int = 10
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @BatchSize NOT BETWEEN 1 AND 100
        THROW 51012, N'Batch size must be between 1 and 100.', 1;
    ;WITH claim AS
    (
        SELECT TOP (@BatchSize) *
        FROM ops.IndexOutbox WITH (READPAST,UPDLOCK,ROWLOCK)
        WHERE EventStatus = 'PENDING'
        ORDER BY CreatedAt, EventID
    )
    UPDATE claim
    SET EventStatus='CLAIMED', AttemptCount=AttemptCount+1,
        ClaimedAt=SYSUTCDATETIME(), LeaseUntil=DATEADD(minute,10,SYSUTCDATETIME()),
        ClaimToken=NEWID(),LastError=NULL
    OUTPUT inserted.EventID,inserted.SourceRevisionID,
           inserted.Operation,inserted.ModelID,inserted.ClaimToken;
END;
GO

CREATE OR ALTER PROCEDURE ops.usp_CompleteIndexOutbox
    @EventID bigint,
    @ClaimToken uniqueidentifier,
    @Succeeded bit,
    @ErrorMessage nvarchar(2000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @SourceRevisionID bigint, @FinalFailure bit=0;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE ops.IndexOutbox
        SET EventStatus=CASE WHEN @Succeeded=1 THEN 'DONE'
                             WHEN AttemptCount >= 3 THEN 'FAILED' ELSE 'PENDING' END,
            ProcessedAt=CASE WHEN @Succeeded=1 THEN SYSUTCDATETIME() ELSE NULL END,
            LeaseUntil=NULL,ClaimToken=NULL,
            LastError=CASE WHEN @Succeeded=1 THEN NULL ELSE @ErrorMessage END
        WHERE EventID=@EventID AND EventStatus='CLAIMED'
          AND ClaimToken=@ClaimToken AND LeaseUntil>SYSUTCDATETIME();
        IF @@ROWCOUNT <> 1
            THROW 51013, N'Outbox claim token is stale or missing.', 1;
        SELECT @SourceRevisionID=SourceRevisionID,
               @FinalFailure=CASE WHEN EventStatus='FAILED' THEN 1 ELSE 0 END
        FROM ops.IndexOutbox WHERE EventID=@EventID;
        IF @FinalFailure=1
        BEGIN
            UPDATE knowledge.SourceRevision
            SET ProcessingStatus='FAILED',ProcessedAt=SYSUTCDATETIME()
            WHERE SourceRevisionID=@SourceRevisionID AND IsCurrent=1;
            UPDATE detail SET DocumentStatus='FAILED'
            FROM social.DocumentDetail AS detail
            JOIN knowledge.SourceRevision AS source
              ON source.ContentID=detail.ContentID
            WHERE source.SourceRevisionID=@SourceRevisionID AND source.IsCurrent=1;
            UPDATE version SET OCRStatus='FAILED'
            FROM knowledge.DocumentVersion AS version
            JOIN knowledge.SourceRevision AS source
              ON source.DocumentVersionID=version.DocumentVersionID
            WHERE source.SourceRevisionID=@SourceRevisionID AND source.IsCurrent=1
              AND version.OCRStatus='PENDING';
        END;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* Explicit operator action after the underlying OCR/model problem is fixed. */
CREATE OR ALTER PROCEDURE ops.usp_RetryIndexOutbox
    @EventID bigint
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE ops.IndexOutbox
    SET EventStatus='PENDING',AttemptCount=0,ClaimedAt=NULL,
        ClaimToken=NULL,LeaseUntil=NULL,ProcessedAt=NULL,LastError=NULL
    WHERE EventID=@EventID
      AND (EventStatus='FAILED'
           OR (EventStatus='CLAIMED' AND LeaseUntil < SYSUTCDATETIME()));
    IF @@ROWCOUNT<>1 THROW 51016, N'Failed or expired outbox event not found.', 1;
END;
GO

/* Idempotent worker retry: remove only evidence owned by this source revision. */
CREATE OR ALTER PROCEDURE ops.usp_ResetSourceIndex
    @SourceRevisionID bigint
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Entities TABLE (EntityID bigint PRIMARY KEY);
    INSERT INTO @Entities (EntityID)
    SELECT DISTINCT entity.EntityID
    FROM knowledge.Chunk AS chunk,
         knowledge.Mentions AS mention,
         knowledge.KnowledgeEntity AS entity
    WHERE MATCH(chunk-(mention)->entity)
      AND chunk.SourceRevisionID=@SourceRevisionID;

    /* SQL Graph does not cascade-delete edges when a node is removed. */
    DELETE FROM knowledge.EntityRelation
    WHERE EvidenceChunkID IN
          (SELECT ChunkID FROM knowledge.Chunk WHERE SourceRevisionID=@SourceRevisionID);
    DELETE FROM knowledge.Mentions
    WHERE EvidenceChunkID IN
          (SELECT ChunkID FROM knowledge.Chunk WHERE SourceRevisionID=@SourceRevisionID);
    DELETE FROM knowledge.ChunkOf
    WHERE $from_id IN
          (SELECT $node_id FROM knowledge.Chunk WHERE SourceRevisionID=@SourceRevisionID);
    DELETE embedding
    FROM knowledge.ChunkEmbedding AS embedding
    JOIN knowledge.Chunk AS chunk ON chunk.ChunkID=embedding.ChunkID
    WHERE chunk.SourceRevisionID=@SourceRevisionID;
    /* Cited chunks remain as stale audit records; live retrieval excludes them. */
    UPDATE knowledge.Chunk SET ChunkStatus='STALE'
    WHERE SourceRevisionID=@SourceRevisionID;
    DELETE chunk
    FROM knowledge.Chunk AS chunk
    WHERE chunk.SourceRevisionID=@SourceRevisionID
      AND NOT EXISTS
          (SELECT 1 FROM assistant.RetrievedChunk AS retrieved
           WHERE retrieved.ChunkID=chunk.ChunkID);
    DELETE entity
    FROM knowledge.KnowledgeEntity AS entity
    JOIN @Entities AS owned ON owned.EntityID=entity.EntityID
    WHERE NOT EXISTS
          (SELECT 1 FROM knowledge.Mentions AS mention
           WHERE mention.$to_id=entity.$node_id)
      AND NOT EXISTS
          (SELECT 1 FROM knowledge.EntityRelation AS relation
           WHERE relation.$from_id=entity.$node_id OR relation.$to_id=entity.$node_id);
END;
GO

/* Revocation changes SQL visibility synchronously; cleanup is asynchronous. */
CREATE OR ALTER PROCEDURE assistant.usp_RevokeContentAccess
    @ActorUserID bigint,
    @ContentID bigint,
    @NewStatus varchar(12) = 'HIDDEN',
    @AllowRag bit = 0,
    @ExpectedKind varchar(8) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @NewStatus IS NULL OR @NewStatus NOT IN ('HIDDEN','DELETED')
        THROW 51014, N'New status must be HIDDEN or DELETED.', 1;
    IF @ExpectedKind IS NOT NULL
       AND @ExpectedKind NOT IN ('POST','COMMENT','DOCUMENT')
        THROW 51035, N'Expected content kind is invalid.', 1;
    DECLARE @ActualKind varchar(8), @ActiveActorUserID bigint;
    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT @ActiveActorUserID = UserID
        FROM auth.UserAccount WITH (UPDLOCK,HOLDLOCK)
        WHERE UserID = @ActorUserID AND AccountStatus = 'ACTIVE';
        IF @ActiveActorUserID IS NULL
            THROW 51036, N'Only an active author may revoke content.', 1;
        SELECT @ActualKind = Kind
        FROM social.ContentItem WITH (UPDLOCK,HOLDLOCK)
        WHERE ContentID = @ContentID;
        IF NOT EXISTS
        (
            SELECT 1
            FROM auth.UserAccount AS author,
                 social.Authored AS authored,
                 social.ContentItem AS item
            WHERE MATCH(author-(authored)->item)
              AND author.UserID=@ActorUserID AND item.ContentID=@ContentID
        ) THROW 51015, N'Only the author may revoke this content.', 1;
        IF @ExpectedKind IS NOT NULL AND @ActualKind <> @ExpectedKind
            THROW 51037, N'Content kind does not match the expected kind.', 1;
        UPDATE social.ContentItem
        SET ContentStatus=@NewStatus,AllowRag=@AllowRag,UpdatedAt=SYSUTCDATETIME()
        WHERE ContentID=@ContentID;
        INSERT INTO ops.IndexOutbox (SourceRevisionID,ModelID,Operation)
        SELECT source.SourceRevisionID,model.ModelID,'DELETE'
        FROM knowledge.SourceRevision AS source
        CROSS JOIN knowledge.EmbeddingModel AS model
        WHERE source.ContentID=@ContentID
          AND model.IsActive=1
          AND NOT EXISTS
          (SELECT 1 FROM ops.IndexOutbox AS queued
           WHERE queued.SourceRevisionID=source.SourceRevisionID
             AND queued.ModelID=model.ModelID
             AND queued.Operation='DELETE'
             AND queued.EventStatus IN ('PENDING','CLAIMED'));
        INSERT INTO ops.AuditEvent (ActorUserID,EventType,EntityType,EntityID)
        VALUES (@ActorUserID,'REVOKE','CONTENT',@ContentID);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* Posts/comments are published and versioned in one transaction. */
CREATE OR ALTER PROCEDURE social.usp_PublishContent
    @AuthorUserID bigint,
    @CommunityID bigint,
    @Kind varchar(8),
    @Body nvarchar(max),
    @Title nvarchar(250) = NULL,
    @ParentPostID bigint = NULL,
    @ContentID bigint = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @Kind NOT IN ('POST','COMMENT') OR NULLIF(LTRIM(RTRIM(@Body)),N'') IS NULL
        THROW 51001, N'Only nonempty posts and comments can be published.', 1;
    IF @Kind = 'POST' AND @ParentPostID IS NOT NULL
        THROW 51002, N'A post cannot have a parent post.', 1;
    IF @Kind = 'COMMENT' AND @ParentPostID IS NULL
        THROW 51003, N'A comment requires a parent post.', 1;
    IF NOT EXISTS (SELECT 1 FROM auth.fn_UserCanWriteCommunity(@AuthorUserID,@CommunityID))
        THROW 51004, N'Author cannot publish in the community.', 1;
    IF @Kind = 'COMMENT' AND NOT EXISTS
       (SELECT 1 FROM social.vAccessibleContent
        WHERE UserID = @AuthorUserID AND ContentID = @ParentPostID
          AND CommunityID = @CommunityID AND Kind = 'POST')
        THROW 51005, N'Parent post is not accessible.', 1;

    DECLARE @RevisionID bigint, @SourceRevisionID bigint, @RevisionNo int,
            @MembershipLockResult int, @LockedContentID bigint,
            @MembershipLockResource nvarchar(255) =
                CONCAT(N'social:community:',@CommunityID,N':membership');
    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC @MembershipLockResult = sys.sp_getapplock
            @Resource = @MembershipLockResource,
            @LockMode = 'Shared', @LockOwner = 'Transaction', @LockTimeout = 5000;
        IF @MembershipLockResult < 0
            THROW 51018, N'Could not lock community membership.', 1;
        IF NOT EXISTS (SELECT 1 FROM auth.fn_UserCanWriteCommunity(@AuthorUserID,@CommunityID))
            THROW 51004, N'Author can no longer publish in the community.', 1;
        IF @Kind = 'COMMENT'
        BEGIN
            SELECT @LockedContentID=ContentID FROM social.ContentItem WITH (UPDLOCK,HOLDLOCK)
            WHERE ContentID=@ParentPostID;
            IF NOT EXISTS
               (SELECT 1 FROM social.vAccessibleContent
                WHERE UserID=@AuthorUserID AND ContentID=@ParentPostID
                  AND CommunityID=@CommunityID AND Kind='POST')
                THROW 51005, N'Parent post is no longer accessible.', 1;
        END;
        IF @ContentID IS NULL
        BEGIN
            INSERT INTO social.ContentItem (Kind,ContentStatus,AllowRag,PublishedAt)
            VALUES (@Kind,'PUBLISHED',1,SYSUTCDATETIME());
            SET @ContentID = CONVERT(bigint,SCOPE_IDENTITY());

            INSERT INTO social.Authored ($from_id,$to_id)
            SELECT author.$node_id, item.$node_id
            FROM auth.UserAccount AS author, social.ContentItem AS item
            WHERE author.UserID = @AuthorUserID AND item.ContentID = @ContentID;

            IF @Kind = 'POST'
                INSERT INTO social.PublishedIn ($from_id,$to_id)
                SELECT item.$node_id, community.$node_id
                FROM social.ContentItem AS item, social.Community AS community
                WHERE item.ContentID = @ContentID AND community.CommunityID = @CommunityID;
            ELSE
                INSERT INTO social.CommentOn ($from_id,$to_id)
                SELECT comment.$node_id, post.$node_id
                FROM social.ContentItem AS comment, social.ContentItem AS post
                WHERE comment.ContentID = @ContentID AND post.ContentID = @ParentPostID;
            SET @RevisionNo = 1;
        END
        ELSE
        BEGIN
            SELECT @LockedContentID=ContentID FROM social.ContentItem WITH (UPDLOCK,HOLDLOCK)
            WHERE ContentID=@ContentID;
            IF NOT EXISTS
            (
                SELECT 1 FROM social.vAccessibleContent AS access
                WHERE access.UserID = @AuthorUserID AND access.ContentID = @ContentID
                  AND access.CommunityID = @CommunityID AND access.Kind = @Kind
                  AND access.AuthorUserID = @AuthorUserID
            ) THROW 51006, N'Only the author may edit this accessible content.', 1;

            SELECT @RevisionNo = COALESCE(MAX(RevisionNo),0)+1
            FROM social.PostRevision WHERE ContentID = @ContentID AND @Kind = 'POST';
            IF @Kind = 'COMMENT'
                SELECT @RevisionNo = COALESCE(MAX(RevisionNo),0)+1
                FROM social.CommentRevision WHERE ContentID = @ContentID;
            UPDATE social.PostRevision SET IsCurrent = 0 WHERE ContentID = @ContentID AND IsCurrent = 1;
            UPDATE social.CommentRevision SET IsCurrent = 0 WHERE ContentID = @ContentID AND IsCurrent = 1;
            UPDATE knowledge.SourceRevision SET IsCurrent = 0 WHERE ContentID = @ContentID AND IsCurrent = 1;
            UPDATE social.ContentItem SET UpdatedAt = SYSUTCDATETIME()
            WHERE ContentID = @ContentID;
        END;

        IF @Kind = 'POST'
        BEGIN
            INSERT INTO social.PostRevision
                (ContentID,RevisionNo,Body,ContentHash,EditedByUserID)
            VALUES (@ContentID,@RevisionNo,@Body,
                    HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Body)),@AuthorUserID);
            SET @RevisionID = CONVERT(bigint,SCOPE_IDENTITY());
            INSERT INTO knowledge.SourceRevision
                (ContentID,PostRevisionID,ExtractedText,TextHash)
            VALUES (@ContentID,@RevisionID,@Body,HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Body)));
        END
        ELSE
        BEGIN
            INSERT INTO social.CommentRevision (ContentID,RevisionNo,Body)
            VALUES (@ContentID,@RevisionNo,@Body);
            SET @RevisionID = CONVERT(bigint,SCOPE_IDENTITY());
            INSERT INTO knowledge.SourceRevision
                (ContentID,CommentRevisionID,ExtractedText,TextHash)
            VALUES (@ContentID,@RevisionID,@Body,HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Body)));
        END;
        SET @SourceRevisionID = CONVERT(bigint,SCOPE_IDENTITY());
        INSERT INTO ops.AuditEvent (ActorUserID,EventType,EntityType,EntityID)
        VALUES (@AuthorUserID,'PUBLISH','CONTENT',@ContentID);
        COMMIT TRANSACTION;
        SELECT @ContentID AS ContentID, @SourceRevisionID AS SourceRevisionID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* The payload lives in SQL; workers extract/OCR it after the short upload transaction. */
CREATE OR ALTER PROCEDURE knowledge.usp_SaveDocumentVersion
    @AuthorUserID bigint,
    @CommunityID bigint,
    @ContentID bigint = NULL,
    @Title nvarchar(250),
    @FileName nvarchar(260) = NULL,
    @MimeType varchar(127),
    @FileBytes varbinary(max) = NULL,
    @PlainText nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NOT EXISTS (SELECT 1 FROM auth.fn_UserCanWriteCommunity(@AuthorUserID,@CommunityID))
        THROW 51007, N'Uploader cannot publish in the community.', 1;
    IF @MimeType NOT IN ('text/plain','application/pdf',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document')
        THROW 51008, N'Unsupported document MIME type.', 1;
    IF (@MimeType = 'text/plain' AND (NULLIF(@PlainText,N'') IS NULL OR @FileBytes IS NOT NULL))
       OR (@MimeType <> 'text/plain' AND (@FileBytes IS NULL OR @PlainText IS NOT NULL))
        THROW 51009, N'Document payload is invalid.', 1;
    DECLARE @SizeBytes bigint = COALESCE(DATALENGTH(@FileBytes),DATALENGTH(@PlainText));
    IF @SizeBytes IS NULL OR @SizeBytes < 1 OR @SizeBytes > 10485760
        THROW 51010, N'Document size must be between 1 byte and 10 MiB.', 1;

    DECLARE @VersionNo int, @DocumentVersionID bigint, @SourceRevisionID bigint,
            @MembershipLockResult int, @LockedContentID bigint,
            @MembershipLockResource nvarchar(255) =
                CONCAT(N'social:community:',@CommunityID,N':membership');
    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC @MembershipLockResult = sys.sp_getapplock
            @Resource = @MembershipLockResource,
            @LockMode = 'Shared', @LockOwner = 'Transaction', @LockTimeout = 5000;
        IF @MembershipLockResult < 0
            THROW 51019, N'Could not lock community membership.', 1;
        IF NOT EXISTS (SELECT 1 FROM auth.fn_UserCanWriteCommunity(@AuthorUserID,@CommunityID))
            THROW 51007, N'Uploader can no longer publish in the community.', 1;
        IF @ContentID IS NULL
        BEGIN
            INSERT INTO social.ContentItem (Kind,ContentStatus,AllowRag,PublishedAt)
            VALUES ('DOCUMENT','PUBLISHED',1,SYSUTCDATETIME());
            SET @ContentID = CONVERT(bigint,SCOPE_IDENTITY());
            INSERT INTO social.DocumentDetail (ContentID,Title,DocumentStatus)
            VALUES (@ContentID,@Title,'PROCESSING');
            INSERT INTO social.Authored ($from_id,$to_id)
            SELECT author.$node_id,item.$node_id
            FROM auth.UserAccount AS author, social.ContentItem AS item
            WHERE author.UserID=@AuthorUserID AND item.ContentID=@ContentID;
            INSERT INTO social.PublishedIn ($from_id,$to_id)
            SELECT item.$node_id,community.$node_id
            FROM social.ContentItem AS item, social.Community AS community
            WHERE item.ContentID=@ContentID AND community.CommunityID=@CommunityID;
            SET @VersionNo = 1;
        END
        ELSE
        BEGIN
            SELECT @LockedContentID=ContentID FROM social.ContentItem WITH (UPDLOCK,HOLDLOCK)
            WHERE ContentID=@ContentID;
            IF NOT EXISTS
            (
                SELECT 1
                FROM auth.UserAccount AS author,
                     social.Authored AS authored,
                     social.ContentItem AS document,
                     social.PublishedIn AS publishedIn,
                     social.Community AS community
                WHERE MATCH(author-(authored)->document)
                  AND MATCH(document-(publishedIn)->community)
                  AND author.UserID=@AuthorUserID
                  AND document.ContentID=@ContentID
                  AND document.Kind='DOCUMENT'
                  AND document.ContentStatus='PUBLISHED'
                  AND community.CommunityID=@CommunityID
            )
                THROW 51011, N'Only the author may update this document.', 1;
            SELECT @VersionNo = COALESCE(MAX(VersionNo),0)+1
            FROM knowledge.DocumentVersion WHERE ContentID=@ContentID;
            UPDATE knowledge.DocumentVersion SET IsCurrent=0 WHERE ContentID=@ContentID AND IsCurrent=1;
            UPDATE knowledge.SourceRevision SET IsCurrent=0 WHERE ContentID=@ContentID AND IsCurrent=1;
            UPDATE social.DocumentDetail SET Title=@Title,DocumentStatus='PROCESSING' WHERE ContentID=@ContentID;
            UPDATE social.ContentItem SET UpdatedAt=SYSUTCDATETIME() WHERE ContentID=@ContentID;
        END;
        INSERT INTO knowledge.DocumentVersion
            (ContentID,VersionNo,FileName,MimeType,FileBytes,PlainText,SizeBytes,SHA256,OCRStatus)
        VALUES (@ContentID,@VersionNo,@FileName,@MimeType,@FileBytes,@PlainText,@SizeBytes,
            HASHBYTES('SHA2_256',COALESCE(@FileBytes,CONVERT(varbinary(max),@PlainText))),
            CASE WHEN @MimeType='application/pdf' THEN 'PENDING' ELSE 'NOT_NEEDED' END);
        SET @DocumentVersionID = CONVERT(bigint,SCOPE_IDENTITY());
        INSERT INTO knowledge.SourceRevision (ContentID,DocumentVersionID)
        VALUES (@ContentID,@DocumentVersionID);
        SET @SourceRevisionID = CONVERT(bigint,SCOPE_IDENTITY());
        INSERT INTO ops.AuditEvent (ActorUserID,EventType,EntityType,EntityID)
        VALUES (@AuthorUserID,'UPLOAD','DOCUMENT',@ContentID);
        COMMIT TRANSACTION;
        SELECT @ContentID AS ContentID,@DocumentVersionID AS DocumentVersionID,
               @SourceRevisionID AS SourceRevisionID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
