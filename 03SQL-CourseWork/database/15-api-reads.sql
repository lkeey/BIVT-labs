/*
 * Read API for a trusted backend. @UserID comes from its verified session;
 * these procedures do not authenticate SQL callers. No procedure exposes
 * document bytes. A page returns at most @Limit + 1 rows: the backend keeps
 * @Limit and uses the last emitted numeric ID as its opaque next cursor.
 */

CREATE OR ALTER PROCEDURE auth.usp_GetUserProfile
    @UserID bigint,
    @ProfileUserID bigint
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS
       (SELECT 1 FROM auth.UserAccount
        WHERE UserID = @UserID AND AccountStatus = 'ACTIVE')
        THROW 51200, N'Active reader is required.', 1;

    SELECT target.UserID, profile.DisplayName, profile.Bio,
           CAST(CASE WHEN EXISTS
           (
               SELECT 1
               FROM auth.UserAccount AS follower,
                    social.Follows AS follows,
                    auth.UserAccount AS followed
               WHERE MATCH(follower-(follows)->followed)
                 AND follower.UserID = @UserID
                 AND followed.UserID = @ProfileUserID
           ) THEN 1 ELSE 0 END AS bit) AS FollowedByMe
    FROM auth.UserAccount AS target
    JOIN auth.UserProfile AS profile ON profile.UserID = target.UserID
    WHERE target.UserID = @ProfileUserID
      AND target.AccountStatus = 'ACTIVE'
      AND (profile.ProfileVisibility = 'PUBLIC' OR target.UserID = @UserID);

    IF @@ROWCOUNT <> 1
        THROW 51201, N'Profile is unavailable.', 1;
END;
GO

/* A current membership is an edge without EndedAt; owner status is canonical. */
CREATE OR ALTER PROCEDURE social.usp_ListCommunities
    @UserID bigint,
    @AfterCommunityID bigint = NULL,
    @Limit int = 20
AS
BEGIN
    SET NOCOUNT ON;
    IF @Limit IS NULL OR @Limit NOT BETWEEN 1 AND 50
       OR (@AfterCommunityID IS NOT NULL AND @AfterCommunityID < 0)
        THROW 51202, N'Invalid community page.', 1;
    IF NOT EXISTS
       (SELECT 1 FROM auth.UserAccount
        WHERE UserID = @UserID AND AccountStatus = 'ACTIVE')
        THROW 51200, N'Active reader is required.', 1;

    ;WITH CurrentMembership AS
    (
        SELECT member.UserID, community.CommunityID, edge.MemberStatus,
               ROW_NUMBER() OVER
               (PARTITION BY member.UserID, community.CommunityID
                ORDER BY edge.MembershipID DESC) AS RowNo
        FROM auth.UserAccount AS member,
             social.MemberOf AS edge,
             social.Community AS community
        WHERE MATCH(member-(edge)->community)
          AND member.UserID = @UserID AND edge.EndedAt IS NULL
    )
    SELECT TOP (@Limit + 1)
           community.CommunityID, community.Slug, community.CommunityName,
           community.Description, community.Visibility, community.OwnerUserID,
           CAST(CASE WHEN community.OwnerUserID = @UserID THEN 'ACTIVE'
                     ELSE COALESCE(membership.MemberStatus, 'NONE')
                END AS varchar(8)) AS MembershipStatus
    FROM social.Community AS community
    CROSS APPLY auth.fn_UserCanReadCommunity(@UserID, community.CommunityID) AS readable
    LEFT JOIN CurrentMembership AS membership
      ON membership.CommunityID = community.CommunityID
     AND membership.UserID = @UserID AND membership.RowNo = 1
    WHERE community.CommunityID > ISNULL(@AfterCommunityID, 0)
    ORDER BY community.CommunityID;
END;
GO

CREATE OR ALTER PROCEDURE social.usp_GetCommunity
    @UserID bigint,
    @CommunityID bigint
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH CurrentMembership AS
    (
        SELECT member.UserID, community.CommunityID, edge.MemberStatus,
               ROW_NUMBER() OVER
               (PARTITION BY member.UserID, community.CommunityID
                ORDER BY edge.MembershipID DESC) AS RowNo
        FROM auth.UserAccount AS member,
             social.MemberOf AS edge,
             social.Community AS community
        WHERE MATCH(member-(edge)->community)
          AND member.UserID = @UserID
          AND community.CommunityID = @CommunityID
          AND edge.EndedAt IS NULL
    )
    SELECT community.CommunityID, community.Slug, community.CommunityName,
           community.Description, community.Visibility, community.OwnerUserID,
           CAST(CASE WHEN community.OwnerUserID = @UserID THEN 'ACTIVE'
                     ELSE COALESCE(membership.MemberStatus, 'NONE')
                END AS varchar(8)) AS MembershipStatus
    FROM social.Community AS community
    CROSS APPLY auth.fn_UserCanReadCommunity(@UserID, community.CommunityID) AS readable
    LEFT JOIN CurrentMembership AS membership
      ON membership.CommunityID = community.CommunityID
     AND membership.UserID = @UserID AND membership.RowNo = 1
    WHERE community.CommunityID = @CommunityID;

    IF @@ROWCOUNT <> 1
        THROW 51203, N'Community is unavailable.', 1;
END;
GO

/* Content pages use the live ACL and only the current published revision. */
CREATE OR ALTER PROCEDURE social.usp_ListPosts
    @UserID bigint,
    @CommunityID bigint,
    @AfterContentID bigint = NULL,
    @Limit int = 20
AS
BEGIN
    SET NOCOUNT ON;
    IF @Limit IS NULL OR @Limit NOT BETWEEN 1 AND 50
       OR (@AfterContentID IS NOT NULL AND @AfterContentID < 0)
        THROW 51204, N'Invalid post page.', 1;
    IF NOT EXISTS
       (SELECT 1 FROM auth.fn_UserCanReadCommunity(@UserID, @CommunityID))
        THROW 51203, N'Community is unavailable.', 1;

    SELECT TOP (@Limit + 1) access.ContentID, access.CommunityID,
           access.AuthorUserID, revision.Body, access.PublishedAt
    FROM social.vAccessibleContent AS access
    JOIN social.PostRevision AS revision
      ON revision.ContentID = access.ContentID AND revision.IsCurrent = 1
    WHERE access.UserID = @UserID
      AND access.CommunityID = @CommunityID
      AND access.Kind = 'POST'
      AND access.ContentID > ISNULL(@AfterContentID, 0)
    ORDER BY access.ContentID;
END;
GO

CREATE OR ALTER PROCEDURE social.usp_GetPost
    @UserID bigint,
    @PostID bigint
AS
BEGIN
    SET NOCOUNT ON;
    SELECT access.ContentID, access.CommunityID, access.AuthorUserID,
           revision.Body, access.PublishedAt
    FROM social.vAccessibleContent AS access
    JOIN social.PostRevision AS revision
      ON revision.ContentID = access.ContentID AND revision.IsCurrent = 1
    WHERE access.UserID = @UserID
      AND access.ContentID = @PostID AND access.Kind = 'POST';

    IF @@ROWCOUNT <> 1
        THROW 51205, N'Post is unavailable.', 1;
END;
GO

CREATE OR ALTER PROCEDURE social.usp_ListComments
    @UserID bigint,
    @PostID bigint,
    @AfterContentID bigint = NULL,
    @Limit int = 20
AS
BEGIN
    SET NOCOUNT ON;
    IF @Limit IS NULL OR @Limit NOT BETWEEN 1 AND 50
       OR (@AfterContentID IS NOT NULL AND @AfterContentID < 0)
        THROW 51206, N'Invalid comment page.', 1;
    IF NOT EXISTS
       (SELECT 1 FROM social.vAccessibleContent
        WHERE UserID = @UserID AND ContentID = @PostID AND Kind = 'POST')
        THROW 51205, N'Post is unavailable.', 1;

    ;WITH CommentParent AS
    (
        SELECT comment.ContentID AS CommentID, post.ContentID AS PostID
        FROM social.ContentItem AS comment,
             social.CommentOn AS commentOn,
             social.ContentItem AS post
        WHERE MATCH(comment-(commentOn)->post)
          AND post.ContentID = @PostID
          AND comment.Kind = 'COMMENT' AND post.Kind = 'POST'
    )
    SELECT TOP (@Limit + 1) access.ContentID, parent.PostID,
           access.AuthorUserID, revision.Body, access.PublishedAt
    FROM CommentParent AS parent
    JOIN social.vAccessibleContent AS access
      ON access.ContentID = parent.CommentID AND access.UserID = @UserID
    JOIN social.CommentRevision AS revision
      ON revision.ContentID = access.ContentID AND revision.IsCurrent = 1
     AND revision.CommentStatus = 'VISIBLE'
    WHERE access.Kind = 'COMMENT'
      AND access.ContentID > ISNULL(@AfterContentID, 0)
    ORDER BY access.ContentID;
END;
GO

CREATE OR ALTER PROCEDURE social.usp_GetComment
    @UserID bigint,
    @CommentID bigint
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH CommentParent AS
    (
        SELECT comment.ContentID AS CommentID, post.ContentID AS PostID
        FROM social.ContentItem AS comment,
             social.CommentOn AS commentOn,
             social.ContentItem AS post
        WHERE MATCH(comment-(commentOn)->post)
          AND comment.ContentID = @CommentID
          AND comment.Kind = 'COMMENT' AND post.Kind = 'POST'
    )
    SELECT access.ContentID, parent.PostID, access.AuthorUserID,
           revision.Body, access.PublishedAt
    FROM CommentParent AS parent
    JOIN social.vAccessibleContent AS access
      ON access.ContentID = parent.CommentID AND access.UserID = @UserID
    JOIN social.CommentRevision AS revision
      ON revision.ContentID = access.ContentID AND revision.IsCurrent = 1
     AND revision.CommentStatus = 'VISIBLE'
    WHERE access.ContentID = @CommentID AND access.Kind = 'COMMENT';

    IF @@ROWCOUNT <> 1
        THROW 51207, N'Comment is unavailable.', 1;
END;
GO

/* Document list and file download intentionally have different projections. */
CREATE OR ALTER PROCEDURE knowledge.usp_ListDocuments
    @UserID bigint,
    @CommunityID bigint,
    @AfterContentID bigint = NULL,
    @Limit int = 20
AS
BEGIN
    SET NOCOUNT ON;
    IF @Limit IS NULL OR @Limit NOT BETWEEN 1 AND 50
       OR (@AfterContentID IS NOT NULL AND @AfterContentID < 0)
        THROW 51208, N'Invalid document page.', 1;
    IF NOT EXISTS
       (SELECT 1 FROM auth.fn_UserCanReadCommunity(@UserID, @CommunityID))
        THROW 51203, N'Community is unavailable.', 1;

    SELECT TOP (@Limit + 1) access.ContentID, access.CommunityID,
           access.AuthorUserID, detail.Title, version.MimeType,
           version.VersionNo, detail.DocumentStatus AS ProcessingStatus
    FROM social.vAccessibleContent AS access
    JOIN social.DocumentDetail AS detail
      ON detail.ContentID = access.ContentID
    JOIN knowledge.DocumentVersion AS version
      ON version.ContentID = detail.ContentID AND version.IsCurrent = 1
    WHERE access.UserID = @UserID
      AND access.CommunityID = @CommunityID
      AND access.Kind = 'DOCUMENT'
      AND detail.DocumentStatus = 'READY'
      AND access.ContentID > ISNULL(@AfterContentID, 0)
    ORDER BY access.ContentID;
END;
GO

/* Authors may inspect processing failures while the community remains readable. */
CREATE OR ALTER PROCEDURE knowledge.usp_GetDocument
    @UserID bigint,
    @DocumentID bigint
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH DocumentGraph AS
    (
        SELECT item.ContentID, community.CommunityID,
               author.UserID AS AuthorUserID
        FROM auth.UserAccount AS author,
             social.Authored AS authored,
             social.ContentItem AS item,
             social.PublishedIn AS publishedIn,
             social.Community AS community
        WHERE MATCH(author-(authored)->item)
          AND MATCH(item-(publishedIn)->community)
          AND item.ContentID = @DocumentID
          AND item.Kind = 'DOCUMENT' AND item.ContentStatus = 'PUBLISHED'
    )
    SELECT graph.ContentID, graph.CommunityID, graph.AuthorUserID,
           detail.Title, version.MimeType, version.VersionNo,
           detail.DocumentStatus AS ProcessingStatus
    FROM DocumentGraph AS graph
    JOIN social.DocumentDetail AS detail ON detail.ContentID = graph.ContentID
    JOIN knowledge.DocumentVersion AS version
      ON version.ContentID = graph.ContentID AND version.IsCurrent = 1
    CROSS APPLY auth.fn_UserCanReadCommunity(@UserID, graph.CommunityID) AS readable
    WHERE detail.DocumentStatus = 'READY'
       OR graph.AuthorUserID = @UserID;

    IF @@ROWCOUNT <> 1
        THROW 51209, N'Document is unavailable.', 1;
END;
GO
