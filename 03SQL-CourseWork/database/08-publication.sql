/* Author deletion is soft: original documents and revisions remain stored. */
CREATE OR ALTER PROCEDURE social.usp_RevokeContentAccess
    @ActorUserID bigint,
    @ContentID bigint,
    @NewStatus varchar(12) = 'HIDDEN',
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
    DECLARE @Affected TABLE (ContentID bigint PRIMARY KEY);
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
        IF NOT EXISTS (SELECT 1 FROM social.ContentItem
                       WHERE ContentID = @ContentID AND AuthorUserID = @ActorUserID)
            THROW 51015, N'Only the author may revoke this content.', 1;
        IF @ExpectedKind IS NOT NULL AND @ActualKind <> @ExpectedKind
            THROW 51037, N'Content kind does not match the expected kind.', 1;
        INSERT INTO @Affected (ContentID) VALUES (@ContentID);
        IF @ActualKind = 'POST'
            INSERT INTO @Affected (ContentID)
            SELECT ContentID FROM social.ContentItem
            WHERE ParentPostID = @ContentID AND Kind = 'COMMENT';

        /* A revoked post also revokes its comments. */
        UPDATE item
        SET ContentStatus=@NewStatus,
            UpdatedAt=SYSUTCDATETIME()
        FROM social.ContentItem AS item
        JOIN @Affected AS affected ON affected.ContentID=item.ContentID;
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
    IF @Kind IS NULL OR @Kind NOT IN ('POST','COMMENT') OR NULLIF(LTRIM(RTRIM(@Body)),N'') IS NULL
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

    DECLARE @RevisionID bigint, @RevisionNo int,
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
            INSERT INTO social.ContentItem (Kind,AuthorUserID,CommunityID,ParentPostID,ParentKind,ContentStatus,PublishedAt)
            VALUES (@Kind,@AuthorUserID,@CommunityID,@ParentPostID,
                    CASE WHEN @Kind = 'COMMENT' THEN 'POST' END,'PUBLISHED',SYSUTCDATETIME());
            SET @ContentID = CONVERT(bigint,SCOPE_IDENTITY());

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
                  AND (@Kind <> 'COMMENT' OR EXISTS
                       (SELECT 1 FROM social.ContentItem WHERE ContentID = @ContentID AND ParentPostID = @ParentPostID))
            ) THROW 51006, N'Only the author may edit this accessible content.', 1;

            SELECT @RevisionNo = COALESCE(MAX(RevisionNo),0)+1
            FROM social.PostRevision WHERE ContentID = @ContentID AND @Kind = 'POST';
            IF @Kind = 'COMMENT'
                SELECT @RevisionNo = COALESCE(MAX(RevisionNo),0)+1
                FROM social.CommentRevision WHERE ContentID = @ContentID;
            UPDATE social.PostRevision SET IsCurrent = 0 WHERE ContentID = @ContentID AND IsCurrent = 1;
            UPDATE social.CommentRevision SET IsCurrent = 0 WHERE ContentID = @ContentID AND IsCurrent = 1;
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
        END
        ELSE
        BEGIN
            INSERT INTO social.CommentRevision (ContentID,RevisionNo,Body)
            VALUES (@ContentID,@RevisionNo,@Body);
            SET @RevisionID = CONVERT(bigint,SCOPE_IDENTITY());
        END;
        INSERT INTO ops.AuditEvent (ActorUserID,EventType,EntityType,EntityID)
        VALUES (@AuthorUserID,'PUBLISH','CONTENT',@ContentID);
        COMMIT TRANSACTION;
        SELECT @ContentID AS ContentID, @RevisionID AS RevisionID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* Store the original payload and its immutable versions; no OCR or indexing. */
CREATE OR ALTER PROCEDURE social.usp_SaveDocumentVersion
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
    IF @MimeType IS NULL OR @MimeType NOT IN ('text/plain','application/pdf',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document')
        THROW 51008, N'Unsupported document MIME type.', 1;
    IF (@MimeType = 'text/plain' AND (NULLIF(@PlainText,N'') IS NULL OR @FileBytes IS NOT NULL))
       OR (@MimeType <> 'text/plain' AND (@FileBytes IS NULL OR @PlainText IS NOT NULL))
        THROW 51009, N'Document payload is invalid.', 1;
    IF NULLIF(LTRIM(RTRIM(@Title)),N'') IS NULL
        THROW 51009, N'Document title is required.', 1;
    IF @MimeType <> 'text/plain' AND NULLIF(LTRIM(RTRIM(@FileName)),N'') IS NULL
        THROW 51009, N'File name is required.', 1;
    DECLARE @SizeBytes bigint = COALESCE(DATALENGTH(@FileBytes),DATALENGTH(@PlainText));
    IF @SizeBytes IS NULL OR @SizeBytes < 1 OR @SizeBytes > 10485760
        THROW 51010, N'Document size must be between 1 byte and 10 MiB.', 1;

    DECLARE @VersionNo int, @DocumentVersionID bigint,
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
            INSERT INTO social.ContentItem (Kind,AuthorUserID,CommunityID,ContentStatus,PublishedAt)
            VALUES ('DOCUMENT',@AuthorUserID,@CommunityID,'PUBLISHED',SYSUTCDATETIME());
            SET @ContentID = CONVERT(bigint,SCOPE_IDENTITY());
            INSERT INTO social.DocumentDetail (ContentID,Title,DocumentStatus)
            VALUES (@ContentID,@Title,'READY');
            SET @VersionNo = 1;
        END
        ELSE
        BEGIN
            SELECT @LockedContentID=ContentID FROM social.ContentItem WITH (UPDLOCK,HOLDLOCK)
            WHERE ContentID=@ContentID;
            IF NOT EXISTS (SELECT 1 FROM social.ContentItem
                           WHERE ContentID = @ContentID AND AuthorUserID = @AuthorUserID
                             AND CommunityID = @CommunityID AND Kind = 'DOCUMENT'
                             AND ContentStatus = 'PUBLISHED')
                THROW 51011, N'Only the author may update this document.', 1;
            SELECT @VersionNo = COALESCE(MAX(VersionNo),0)+1
            FROM social.DocumentVersion WHERE ContentID=@ContentID;
            UPDATE social.DocumentVersion SET IsCurrent=0 WHERE ContentID=@ContentID AND IsCurrent=1;
            UPDATE social.DocumentDetail SET Title=@Title,DocumentStatus='READY' WHERE ContentID=@ContentID;
            UPDATE social.ContentItem SET UpdatedAt=SYSUTCDATETIME() WHERE ContentID=@ContentID;
        END;
        INSERT INTO social.DocumentVersion
            (ContentID,VersionNo,FileName,MimeType,FileBytes,PlainText,SizeBytes,SHA256)
        VALUES (@ContentID,@VersionNo,@FileName,@MimeType,@FileBytes,@PlainText,@SizeBytes,
            HASHBYTES('SHA2_256',COALESCE(@FileBytes,CONVERT(varbinary(max),@PlainText))));
        SET @DocumentVersionID = CONVERT(bigint,SCOPE_IDENTITY());
        INSERT INTO ops.AuditEvent (ActorUserID,EventType,EntityType,EntityID)
        VALUES (@AuthorUserID,'UPLOAD','DOCUMENT',@ContentID);
        COMMIT TRANSACTION;
        SELECT @ContentID AS ContentID,@DocumentVersionID AS DocumentVersionID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
