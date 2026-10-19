/* Optional, repeatable demo data. Run after 00–10 in a disposable course database. */
SET NOCOUNT ON;
INSERT INTO auth.UserAccount (Login,EmailNormalized)
SELECT seed.Login,seed.Email
FROM (VALUES (N'demo_alice',N'alice@example.invalid'),
             (N'demo_bob',N'bob@example.invalid'),
             (N'demo_charlie',N'charlie@example.invalid')) AS seed(Login,Email)
WHERE NOT EXISTS (SELECT 1 FROM auth.UserAccount AS existing WHERE existing.Login=seed.Login);

INSERT INTO auth.UserProfile (UserID,DisplayName)
SELECT account.UserID,
       CASE account.Login WHEN N'demo_alice' THEN N'Алиса'
                          WHEN N'demo_bob' THEN N'Борис' ELSE N'Чарли' END
FROM auth.UserAccount AS account
WHERE account.Login IN (N'demo_alice',N'demo_bob',N'demo_charlie')
  AND NOT EXISTS (SELECT 1 FROM auth.UserProfile AS existing
                  WHERE existing.UserID=account.UserID);

DECLARE @Alice bigint=(SELECT UserID FROM auth.UserAccount WHERE Login=N'demo_alice');
DECLARE @Bob bigint=(SELECT UserID FROM auth.UserAccount WHERE Login=N'demo_bob');
DECLARE @Charlie bigint=(SELECT UserID FROM auth.UserAccount WHERE Login=N'demo_charlie');

IF NOT EXISTS (SELECT 1 FROM social.Community WHERE CommunityName=N'Демо: закрытая группа')
    INSERT INTO social.Community (OwnerUserID,Slug,CommunityName,Visibility)
    VALUES (@Alice,N'demo-private',N'Демо: закрытая группа','PRIVATE');
IF NOT EXISTS (SELECT 1 FROM social.Community WHERE CommunityName=N'Демо: открытая группа')
    INSERT INTO social.Community (OwnerUserID,Slug,CommunityName,Visibility)
    VALUES (@Alice,N'demo-public',N'Демо: открытая группа','PUBLIC');
DECLARE @Private bigint=(SELECT CommunityID FROM social.Community
                         WHERE CommunityName=N'Демо: закрытая группа');
DECLARE @Public bigint=(SELECT CommunityID FROM social.Community
                        WHERE CommunityName=N'Демо: открытая группа');

IF NOT EXISTS
   (SELECT 1 FROM auth.UserAccount AS member,social.MemberOf AS edge,social.Community AS community
    WHERE MATCH(member-(edge)->community)
      AND member.UserID=@Bob AND community.CommunityID=@Private AND edge.MemberStatus='ACTIVE')
    INSERT INTO social.MemberOf ($from_id,$to_id,MemberStatus)
    SELECT member.$node_id,community.$node_id,'ACTIVE'
    FROM auth.UserAccount AS member,social.Community AS community
    WHERE member.UserID=@Bob AND community.CommunityID=@Private;

IF NOT EXISTS
   (SELECT 1 FROM auth.UserAccount AS member,social.MemberOf AS edge,social.Community AS community
    WHERE MATCH(member-(edge)->community)
      AND member.UserID=@Charlie AND community.CommunityID=@Private)
    INSERT INTO social.MemberOf ($from_id,$to_id,MemberStatus)
    SELECT member.$node_id,community.$node_id,'PENDING'
    FROM auth.UserAccount AS member,social.Community AS community
    WHERE member.UserID=@Charlie AND community.CommunityID=@Private;

IF NOT EXISTS
   (SELECT 1 FROM auth.UserAccount AS follower,social.Follows AS edge,auth.UserAccount AS followed
    WHERE MATCH(follower-(edge)->followed)
      AND follower.UserID=@Bob AND followed.UserID=@Alice)
    INSERT INTO social.Follows ($from_id,$to_id)
    SELECT follower.$node_id,followed.$node_id
    FROM auth.UserAccount AS follower,auth.UserAccount AS followed
    WHERE follower.UserID=@Bob AND followed.UserID=@Alice;

DECLARE @PrivatePost bigint;
SELECT TOP (1) @PrivatePost=post.ContentID
FROM social.PostRevision AS post
WHERE post.Body=N'В закрытой группе обсуждаем методичку по SQL Graph.';
IF @PrivatePost IS NULL
BEGIN
    DECLARE @CreatedPost TABLE (ContentID bigint,SourceRevisionID bigint);
    INSERT INTO @CreatedPost EXEC social.usp_PublishContent
        @AuthorUserID=@Alice,@CommunityID=@Private,@Kind='POST',
        @Body=N'В закрытой группе обсуждаем методичку по SQL Graph.';
    SELECT @PrivatePost=ContentID FROM @CreatedPost;
END;

IF NOT EXISTS
   (SELECT 1 FROM social.CommentRevision
    WHERE Body=N'Уточнение: каждый извлечённый факт должен иметь источник.')
    EXEC social.usp_PublishContent
        @AuthorUserID=@Bob,@CommunityID=@Private,@Kind='COMMENT',
        @Body=N'Уточнение: каждый извлечённый факт должен иметь источник.',
        @ParentPostID=@PrivatePost;

IF NOT EXISTS
   (SELECT 1 FROM social.PostRevision
    WHERE Body=N'Открытая заметка: RAG цитирует найденные фрагменты.')
    EXEC social.usp_PublishContent
        @AuthorUserID=@Alice,@CommunityID=@Public,@Kind='POST',
        @Body=N'Открытая заметка: RAG цитирует найденные фрагменты.';

/* The worker can extract a person, organization, event, place and two relations. */
IF NOT EXISTS
   (SELECT 1 FROM social.PostRevision
    WHERE Body=N'Иван Петров работает в компании «Яндекс». Конференция «Data Fest» проходит в Москве. Тема: графовые базы данных.')
    EXEC social.usp_PublishContent
        @AuthorUserID=@Alice,@CommunityID=@Public,@Kind='POST',
        @Body=N'Иван Петров работает в компании «Яндекс». Конференция «Data Fest» проходит в Москве. Тема: графовые базы данных.';

IF NOT EXISTS
   (SELECT 1 FROM social.DocumentDetail WHERE Title=N'Демо: правила доступа')
    EXEC knowledge.usp_SaveDocumentVersion
        @AuthorUserID=@Alice,@CommunityID=@Private,
        @Title=N'Демо: правила доступа',@MimeType='text/plain',
        @PlainText=N'Закрытые сообщества доступны только владельцу и активным участникам. Ожидающая заявка не открывает доступ.';

/* The app worker must process pending outbox rows before RAG queries. */
SELECT EventID,SourceRevisionID,Operation,EventStatus
FROM ops.IndexOutbox ORDER BY EventID;

/* Boris is active; Charlie has only a pending request. */
SELECT N'active member' AS DemoCase,ContentID,Kind,CommunityID
FROM social.vAccessibleContent WHERE UserID=@Bob AND CommunityID=@Private;
SELECT N'pending outsider' AS DemoCase,ContentID,Kind,CommunityID
FROM social.vAccessibleContent WHERE UserID=@Charlie AND CommunityID=@Private;
