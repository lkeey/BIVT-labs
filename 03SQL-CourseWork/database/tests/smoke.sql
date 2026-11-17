/* Run after schema installation, in a disposable coursework database.
   All test data rolls back. Errors fail sqlcmd -b. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
BEGIN TRY
    BEGIN TRANSACTION;
    IF (SELECT COUNT(*) FROM sys.tables WHERE is_node=1 OR is_edge=1) <> 2
        THROW 51400, 'Expected exactly two graph tables.', 1;
    DECLARE @Suffix nvarchar(36)=CONVERT(nvarchar(36),NEWID()), @Author bigint, @Reader bigint,
            @Community bigint, @Post bigint, @Comment bigint, @Document bigint;
    INSERT INTO auth.UserAccount(Login,EmailNormalized)
    VALUES (N'smoke-author-'+@Suffix,N'author-'+@Suffix+N'@example.invalid');
    SET @Author=CONVERT(bigint,SCOPE_IDENTITY());
    INSERT INTO auth.UserAccount(Login,EmailNormalized)
    VALUES (N'smoke-reader-'+@Suffix,N'reader-'+@Suffix+N'@example.invalid');
    SET @Reader=CONVERT(bigint,SCOPE_IDENTITY());
    IF (SELECT COUNT(*) FROM social.UserNode WHERE UserID IN (@Author,@Reader)) <> 2
        THROW 51401, 'Account trigger did not create graph nodes.', 1;
    INSERT INTO social.Community(OwnerUserID,Slug,CommunityName,Visibility)
    VALUES (@Author,N'smoke-'+@Suffix,N'Smoke private community','PRIVATE');
    SET @Community=CONVERT(bigint,SCOPE_IDENTITY());
    IF EXISTS (SELECT 1 FROM auth.fn_UserCanReadCommunity(@Reader,@Community))
        THROW 51402, 'Private community leaked to outsider.', 1;
    EXEC social.usp_RequestMembership @Reader,@Community;
    IF EXISTS (SELECT 1 FROM auth.fn_UserCanReadCommunity(@Reader,@Community))
        THROW 51403, 'Pending membership grants access.', 1;
    EXEC social.usp_SetMembership @Author,@Community,@Reader,'ACTIVE','MEMBER';
    IF NOT EXISTS (SELECT 1 FROM auth.fn_UserCanReadCommunity(@Reader,@Community))
        THROW 51404, 'Active membership lacks access.', 1;
    DECLARE @Published TABLE(ContentID bigint,RevisionID bigint);
    INSERT INTO @Published EXEC social.usp_PublishContent @Author,@Community,'POST',N'First post';
    SELECT @Post=ContentID FROM @Published;
    /* CHECK must reject NULL as well as a wrong parent kind.
       Statement-only rollback keeps the outer test transaction usable. */
    SET XACT_ABORT OFF;
    BEGIN TRY
        INSERT INTO social.ContentItem(Kind,AuthorUserID,CommunityID,ParentPostID,ParentKind)
        VALUES ('COMMENT',@Reader,@Community,@Post,NULL);
        THROW 51414, 'NULL ParentKind bypassed the comment constraint.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() <> 547 THROW;
    END CATCH;
    SET XACT_ABORT ON;
    DELETE FROM @Published;
    INSERT INTO @Published EXEC social.usp_PublishContent @Reader,@Community,'COMMENT',N'A comment',NULL,@Post;
    SELECT @Comment=ContentID FROM @Published;
    IF NOT EXISTS (SELECT 1 FROM social.ContentItem WHERE ContentID=@Comment AND ParentPostID=@Post)
        THROW 51405, 'Comment parent link missing.', 1;
    EXEC social.usp_SetReaction @Reader,@Post,'LIKE';
    EXEC social.usp_SetReaction @Reader,@Post,'HELPFUL';
    IF (SELECT COUNT(*) FROM social.ReactTo WHERE UserID=@Reader AND ContentID=@Post) <> 1
        THROW 51406, 'Reaction upsert duplicated a row.', 1;
    EXEC social.usp_SetFollow @Reader,@Author,1;
    EXEC social.usp_SetFollow @Reader,@Author,1;
    DECLARE @Feed TABLE([Rank] bigint,ContentID bigint,Kind varchar(8),Score decimal(9,6),
        ReasonCode varchar(40),ReasonText nvarchar(500),CommunityID bigint,AuthorUserID bigint);
    INSERT INTO @Feed EXEC social.usp_BuildRecommendationFeed @Reader,50;
    IF NOT EXISTS (SELECT 1 FROM @Feed WHERE ContentID=@Post AND ReasonCode='FOLLOWED_AUTHOR')
        THROW 51407, 'Followed author absent from accessible feed.', 1;
    DECLARE @Saved TABLE(ContentID bigint,DocumentVersionID bigint);
    INSERT INTO @Saved EXEC social.usp_SaveDocumentVersion @Author,@Community,NULL,N'Original',N'demo.pdf','application/pdf',0x255044462D,NULL;
    SELECT @Document=ContentID FROM @Saved;
    DELETE FROM @Saved;
    INSERT INTO @Saved EXEC social.usp_SaveDocumentVersion @Author,@Community,@Document,N'Updated',N'demo.pdf','application/pdf',0x255044462D32,NULL;
    IF (SELECT COUNT(*) FROM social.DocumentVersion WHERE ContentID=@Document) <> 2
        THROW 51408, 'Document history was not preserved.', 1;
    IF NOT EXISTS (SELECT 1 FROM social.DocumentVersion WHERE ContentID=@Document AND VersionNo=1 AND FileBytes=0x255044462D AND IsCurrent=0)
        THROW 51409, 'Original document bytes changed.', 1;
    EXEC social.usp_SetMembership @Author,@Community,@Reader,'BLOCKED','MEMBER';
    IF EXISTS (SELECT 1 FROM social.vAccessibleContent WHERE UserID=@Reader AND CommunityID=@Community)
        THROW 51410, 'Blocked reader can see content.', 1;
    EXEC social.usp_RevokeContentAccess @Author,@Document,'DELETED','DOCUMENT';
    IF EXISTS (SELECT 1 FROM social.vAccessibleContent WHERE ContentID=@Document)
        THROW 51411, 'Deleted document remains accessible.', 1;
    IF (SELECT COUNT(*) FROM social.DocumentVersion WHERE ContentID=@Document) <> 2
        THROW 51412, 'Soft deletion destroyed document versions.', 1;
    EXEC social.usp_RevokeContentAccess @Author,@Post,'HIDDEN','POST';
    IF EXISTS (SELECT 1 FROM social.vAccessibleContent WHERE ContentID IN (@Post,@Comment))
        THROW 51413, 'Revoked post or comment remains accessible.', 1;
    ROLLBACK TRANSACTION;
    PRINT 'PASS: relational data, membership ACL, follow graph, feed and preserved document versions';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
