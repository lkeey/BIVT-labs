/* A transparent feed: followed authors, joined communities, then newest posts.
   No persistent ranking batches, semantic models, or derived knowledge graph. */
CREATE OR ALTER PROCEDURE social.usp_BuildRecommendationFeed
    @UserID bigint,
    @Limit int = 20
AS
BEGIN
    SET NOCOUNT ON;
    IF @Limit IS NULL OR @Limit NOT BETWEEN 1 AND 50
        THROW 51060, N'Feed limit must be between 1 and 50.', 1;
    IF NOT EXISTS (SELECT 1 FROM auth.UserAccount WHERE UserID = @UserID AND AccountStatus = 'ACTIVE')
        THROW 51200, N'Active reader is required.', 1;

    ;WITH Candidates AS
    (
        SELECT access.ContentID, access.Kind, access.CommunityID,
               access.AuthorUserID, access.PublishedAt,
               CASE WHEN EXISTS
                    (SELECT 1 FROM social.UserNode AS follower,
                                   social.Follows AS edge, social.UserNode AS followed
                     WHERE MATCH(follower-(edge)->followed)
                       AND follower.UserID = @UserID AND followed.UserID = access.AuthorUserID)
                    THEN 1 ELSE 0 END AS Followed,
               CASE WHEN EXISTS
                    (SELECT 1 FROM social.Community AS c WHERE c.CommunityID = access.CommunityID AND c.OwnerUserID = @UserID)
                      OR EXISTS
                    (SELECT 1 FROM social.MemberOf AS m WHERE m.UserID = @UserID
                       AND m.CommunityID = access.CommunityID AND m.MemberStatus = 'ACTIVE' AND m.EndedAt IS NULL)
                    THEN 1 ELSE 0 END AS Joined
        FROM social.vAccessibleContent AS access
        WHERE access.UserID = @UserID AND access.Kind IN ('POST','DOCUMENT')
    ), Ranked AS
    (
        SELECT *, ROW_NUMBER() OVER
            (ORDER BY Followed DESC, Joined DESC, PublishedAt DESC, ContentID DESC) AS FeedRank
        FROM Candidates
    )
    SELECT TOP (@Limit) FeedRank AS [Rank], ContentID, Kind,
           CAST(2 * Followed + Joined AS decimal(9,6)) AS Score,
           CASE WHEN Followed = 1 THEN 'FOLLOWED_AUTHOR'
                WHEN Joined = 1 THEN 'MEMBER_COMMUNITY' ELSE 'FRESH' END AS ReasonCode,
           CASE WHEN Followed = 1 THEN N'Автор, на которого вы подписаны'
                WHEN Joined = 1 THEN N'Из вашего сообщества'
                ELSE N'Недавно опубликовано' END AS ReasonText,
           CommunityID, AuthorUserID
    FROM Ranked ORDER BY FeedRank;
END;
GO
