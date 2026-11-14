/* Optional synthetic demonstration data. Skip this file in a real installation.
   Repeated application does not duplicate users, communities or materials.
   These accounts have no passwords or Firebase credentials. */
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM auth.UserAccount WHERE Login = N'demo-author')
        INSERT INTO auth.UserAccount(Login,EmailNormalized) VALUES (N'demo-author',N'author@example.invalid');
    IF NOT EXISTS (SELECT 1 FROM auth.UserAccount WHERE Login = N'demo-reader')
        INSERT INTO auth.UserAccount(Login,EmailNormalized) VALUES (N'demo-reader',N'reader@example.invalid');
    IF NOT EXISTS (SELECT 1 FROM auth.UserAccount WHERE Login = N'demo-mentor')
        INSERT INTO auth.UserAccount(Login,EmailNormalized) VALUES (N'demo-mentor',N'mentor@example.invalid');
    DECLARE @Mentor bigint = (SELECT UserID FROM auth.UserAccount WHERE Login = N'demo-mentor');
    IF NOT EXISTS (SELECT 1 FROM auth.UserProfile WHERE UserID = @Mentor)
        INSERT INTO auth.UserProfile(UserID,DisplayName) VALUES (@Mentor,N'Учебный наставник');
    DECLARE @Author bigint = (SELECT UserID FROM auth.UserAccount WHERE Login = N'demo-author'),
            @Reader bigint = (SELECT UserID FROM auth.UserAccount WHERE Login = N'demo-reader');
    IF NOT EXISTS (SELECT 1 FROM auth.UserProfile WHERE UserID = @Author)
        INSERT INTO auth.UserProfile(UserID,DisplayName) VALUES (@Author,N'Учебный автор');
    IF NOT EXISTS (SELECT 1 FROM auth.UserProfile WHERE UserID = @Reader)
        INSERT INTO auth.UserProfile(UserID,DisplayName) VALUES (@Reader,N'Учебный читатель');
    IF NOT EXISTS (SELECT 1 FROM social.Community WHERE Slug = N'demo-databases')
        INSERT INTO social.Community(OwnerUserID,Slug,CommunityName,Visibility)
        VALUES (@Author,N'demo-databases',N'Базы данных','PUBLIC');
    DECLARE @Community bigint = (SELECT CommunityID FROM social.Community WHERE Slug = N'demo-databases');
    IF NOT EXISTS (SELECT 1 FROM social.MemberOf WHERE UserID = @Reader AND CommunityID = @Community AND EndedAt IS NULL)
        INSERT INTO social.MemberOf(UserID,CommunityID,MemberStatus) VALUES (@Reader,@Community,'ACTIVE');
    IF NOT EXISTS (SELECT 1 FROM social.Follows AS f
                   WHERE f.$from_id = (SELECT $node_id FROM social.UserNode WHERE UserID = @Reader)
                     AND f.$to_id = (SELECT $node_id FROM social.UserNode WHERE UserID = @Author))
        INSERT INTO social.Follows($from_id,$to_id)
        SELECT reader.$node_id, author.$node_id FROM social.UserNode AS reader, social.UserNode AS author
        WHERE reader.UserID = @Reader AND author.UserID = @Author;
    IF NOT EXISTS (SELECT 1 FROM social.Follows AS f
                   WHERE f.$from_id = (SELECT $node_id FROM social.UserNode WHERE UserID = @Author)
                     AND f.$to_id = (SELECT $node_id FROM social.UserNode WHERE UserID = @Mentor))
        INSERT INTO social.Follows($from_id,$to_id)
        SELECT author.$node_id, mentor.$node_id FROM social.UserNode AS author, social.UserNode AS mentor
        WHERE author.UserID = @Author AND mentor.UserID = @Mentor;
    IF NOT EXISTS (SELECT 1 FROM social.ContentItem WHERE AuthorUserID = @Author AND CommunityID = @Community AND Kind = 'POST')
    BEGIN
        INSERT INTO social.ContentItem(Kind,AuthorUserID,CommunityID,ContentStatus,PublishedAt)
        VALUES ('POST',@Author,@Community,'PUBLISHED',SYSUTCDATETIME());
        DECLARE @Post bigint = CONVERT(bigint,SCOPE_IDENTITY()),
                @Body nvarchar(max) = N'Реляционная модель: первичные ключи, внешние ключи и нормализация.';
        INSERT INTO social.PostRevision(ContentID,RevisionNo,Body,ContentHash,EditedByUserID)
        VALUES (@Post,1,@Body,HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Body)),@Author);
    END;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
/* A two-hop graph query for a defense demo, not a separate graph data model. */
SELECT DISTINCT me.UserID AS ReaderID, candidate.UserID AS SuggestedUserID
FROM social.UserNode AS me, social.Follows AS firstHop, social.UserNode AS friend,
     social.Follows AS secondHop, social.UserNode AS candidate
WHERE MATCH(me-(firstHop)->friend-(secondHop)->candidate)
  AND me.UserID <> candidate.UserID
  AND NOT EXISTS (SELECT 1 FROM social.Follows AS direct
                  WHERE direct.$from_id = me.$node_id AND direct.$to_id = candidate.$node_id);
GO
