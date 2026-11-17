/* All reads use live relational ACL, including feed and file downloads. */
CREATE OR ALTER FUNCTION auth.fn_UserCanReadCommunity(@UserID bigint, @CommunityID bigint)
RETURNS TABLE AS RETURN
(
    SELECT CAST(1 AS bit) AS CanRead
    FROM auth.UserAccount AS u
    JOIN social.Community AS c ON c.CommunityID = @CommunityID
    WHERE u.UserID = @UserID AND u.AccountStatus = 'ACTIVE' AND c.Status = 'ACTIVE'
      AND NOT EXISTS (SELECT 1 FROM social.MemberOf AS m
                      WHERE m.UserID = @UserID AND m.CommunityID = @CommunityID
                        AND m.MemberStatus IN ('BLOCKED','BANNED') AND m.EndedAt IS NULL)
      AND (c.Visibility = 'PUBLIC' OR c.OwnerUserID = @UserID
           OR EXISTS (SELECT 1 FROM social.MemberOf AS m
                      WHERE m.UserID = @UserID AND m.CommunityID = @CommunityID
                        AND m.MemberStatus = 'ACTIVE' AND m.EndedAt IS NULL))
);
GO
CREATE OR ALTER FUNCTION auth.fn_UserCanWriteCommunity(@UserID bigint, @CommunityID bigint)
RETURNS TABLE AS RETURN
(
    SELECT CAST(1 AS bit) AS CanWrite
    FROM auth.fn_UserCanReadCommunity(@UserID,@CommunityID) AS readable
    WHERE EXISTS (SELECT 1 FROM social.Community WHERE CommunityID = @CommunityID AND OwnerUserID = @UserID)
       OR EXISTS (SELECT 1 FROM social.MemberOf
                  WHERE UserID = @UserID AND CommunityID = @CommunityID
                    AND MemberStatus = 'ACTIVE' AND EndedAt IS NULL)
);
GO
CREATE OR ALTER VIEW social.vAccessibleContent AS
SELECT reader.UserID, item.ContentID, item.Kind, item.CommunityID,
       item.AuthorUserID, item.PublishedAt
FROM auth.UserAccount AS reader
JOIN social.ContentItem AS item ON item.ContentStatus = 'PUBLISHED'
CROSS APPLY auth.fn_UserCanReadCommunity(reader.UserID,item.CommunityID) AS readable
WHERE reader.AccountStatus = 'ACTIVE'
  AND ((item.Kind = 'POST' AND EXISTS
        (SELECT 1 FROM social.PostRevision WHERE ContentID = item.ContentID AND IsCurrent = 1))
    OR (item.Kind = 'COMMENT' AND EXISTS
        (SELECT 1 FROM social.ContentItem AS parent
         JOIN social.PostRevision AS pr ON pr.ContentID = parent.ContentID AND pr.IsCurrent = 1
         WHERE parent.ContentID = item.ParentPostID AND parent.Kind = 'POST'
           AND parent.ContentStatus = 'PUBLISHED') AND EXISTS
        (SELECT 1 FROM social.CommentRevision WHERE ContentID = item.ContentID AND IsCurrent = 1 AND CommentStatus = 'VISIBLE'))
    OR (item.Kind = 'DOCUMENT' AND EXISTS
        (SELECT 1 FROM social.DocumentDetail AS d
         JOIN social.DocumentVersion AS v ON v.ContentID = d.ContentID AND v.IsCurrent = 1
         WHERE d.ContentID = item.ContentID AND d.DocumentStatus = 'READY')));
GO
