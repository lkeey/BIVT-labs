/* All read paths use the same live ACL. These views deliberately expose no file bytes. */
CREATE OR ALTER FUNCTION auth.fn_UserCanReadCommunity
(
    @UserID bigint,
    @CommunityID bigint
)
RETURNS TABLE
AS
RETURN
(
    SELECT CAST(1 AS bit) AS CanRead
    FROM auth.UserAccount AS u
    JOIN social.Community AS c ON c.CommunityID = @CommunityID
    WHERE u.UserID = @UserID
      AND u.AccountStatus = 'ACTIVE'
      AND c.Status = 'ACTIVE'
      AND NOT EXISTS
      (
          SELECT 1
          FROM auth.UserAccount AS blockedUser,
               social.MemberOf AS blockedMembership,
               social.Community AS blockedCommunity
          WHERE MATCH(blockedUser-(blockedMembership)->blockedCommunity)
            AND blockedUser.UserID = @UserID
            AND blockedCommunity.CommunityID = @CommunityID
            AND blockedMembership.MemberStatus IN ('BLOCKED', 'BANNED')
            AND blockedMembership.EndedAt IS NULL
      )
      AND
      (
          c.Visibility = 'PUBLIC'
          OR c.OwnerUserID = @UserID
          OR EXISTS
          (
              SELECT 1
              FROM auth.UserAccount AS member,
                   social.MemberOf AS membership,
                   social.Community AS joinedCommunity
              WHERE MATCH(member-(membership)->joinedCommunity)
                AND member.UserID = @UserID
                AND joinedCommunity.CommunityID = @CommunityID
                AND membership.MemberStatus = 'ACTIVE'
          )
      )
);
GO

/* Reading a public community does not grant permission to publish in it. */
CREATE OR ALTER FUNCTION auth.fn_UserCanWriteCommunity
(
    @UserID bigint,
    @CommunityID bigint
)
RETURNS TABLE
AS
RETURN
(
    SELECT CAST(1 AS bit) AS CanWrite
    FROM auth.fn_UserCanReadCommunity(@UserID, @CommunityID) AS readable
    WHERE EXISTS
          (SELECT 1 FROM social.Community AS owned
           WHERE owned.CommunityID = @CommunityID AND owned.OwnerUserID = @UserID)
       OR EXISTS
          (
              SELECT 1
              FROM auth.UserAccount AS member,
                   social.MemberOf AS membership,
                   social.Community AS joinedCommunity
              WHERE MATCH(member-(membership)->joinedCommunity)
                AND member.UserID = @UserID
                AND joinedCommunity.CommunityID = @CommunityID
                AND membership.MemberStatus = 'ACTIVE'
                AND membership.EndedAt IS NULL
          )
);
GO

/* Comments inherit the parent post's community, rather than trusting a second location. */
CREATE OR ALTER VIEW social.vAccessibleContent
AS
WITH Locations AS
(
    SELECT item.ContentID, community.CommunityID
    FROM social.ContentItem AS item,
         social.PublishedIn AS publishedIn,
         social.Community AS community
    WHERE MATCH(item-(publishedIn)->community)
      AND item.Kind IN ('POST', 'DOCUMENT')
    UNION
    SELECT comment.ContentID, community.CommunityID
    FROM social.ContentItem AS comment,
         social.CommentOn AS commentOn,
         social.ContentItem AS post,
         social.PublishedIn AS publishedIn,
         social.Community AS community
    WHERE MATCH(comment-(commentOn)->post)
      AND MATCH(post-(publishedIn)->community)
      AND comment.Kind = 'COMMENT'
      AND post.Kind = 'POST'
      AND post.ContentStatus = 'PUBLISHED'
),
Authors AS
(
    SELECT item.ContentID, author.UserID AS AuthorUserID
    FROM auth.UserAccount AS author,
         social.Authored AS authored,
         social.ContentItem AS item
    WHERE MATCH(author-(authored)->item)
)
SELECT reader.UserID, item.ContentID, item.Kind, location.CommunityID,
       author.AuthorUserID, item.PublishedAt
FROM auth.UserAccount AS reader
JOIN social.ContentItem AS item ON item.ContentStatus = 'PUBLISHED'
JOIN Locations AS location ON location.ContentID = item.ContentID
JOIN Authors AS author ON author.ContentID = item.ContentID
CROSS APPLY auth.fn_UserCanReadCommunity(reader.UserID, location.CommunityID) AS canRead
WHERE reader.AccountStatus = 'ACTIVE'
  AND
  (
      (item.Kind = 'POST' AND EXISTS
       (SELECT 1 FROM social.PostRevision AS r
        WHERE r.ContentID = item.ContentID AND r.IsCurrent = 1))
      OR (item.Kind = 'COMMENT' AND EXISTS
       (SELECT 1 FROM social.CommentRevision AS r
        WHERE r.ContentID = item.ContentID AND r.IsCurrent = 1
          AND r.CommentStatus = 'VISIBLE'))
      OR (item.Kind = 'DOCUMENT' AND EXISTS
       (SELECT 1 FROM social.DocumentDetail AS d
        JOIN knowledge.DocumentVersion AS v ON v.ContentID = d.ContentID
        WHERE d.ContentID = item.ContentID AND d.DocumentStatus = 'READY'
          AND v.IsCurrent = 1))
  );
GO

CREATE OR ALTER VIEW knowledge.vCurrentRagChunks
AS
SELECT chunk.ChunkID, chunk.SourceRevisionID, source.ContentID,
       chunk.ChunkText, chunk.PageNo, chunk.StartOffset, chunk.EndOffset,
       chunk.ChunkHash, item.Kind,
       COALESCE(document.Title,
                LEFT(post.Body, 120), LEFT(comment.Body, 120)) AS Title
FROM knowledge.Chunk AS chunk
JOIN knowledge.SourceRevision AS source
  ON source.SourceRevisionID = chunk.SourceRevisionID
JOIN social.ContentItem AS item ON item.ContentID = source.ContentID
LEFT JOIN social.PostRevision AS post ON post.RevisionID = source.PostRevisionID
LEFT JOIN social.CommentRevision AS comment ON comment.RevisionID = source.CommentRevisionID
LEFT JOIN social.DocumentDetail AS document ON document.ContentID = source.ContentID
WHERE item.ContentStatus = 'PUBLISHED'
  AND item.AllowRag = 1
  AND source.IsCurrent = 1
  AND source.ProcessingStatus = 'READY'
  AND chunk.ChunkStatus = 'READY'
  AND (post.RevisionID IS NULL OR post.IsCurrent = 1)
  AND (comment.RevisionID IS NULL OR
       (comment.IsCurrent = 1 AND comment.CommentStatus = 'VISIBLE'))
  AND (source.DocumentVersionID IS NULL OR EXISTS
       (SELECT 1 FROM knowledge.DocumentVersion AS version
        WHERE version.DocumentVersionID = source.DocumentVersionID
          AND version.IsCurrent = 1));
GO

/* Historical answers are shown only while each citation is still readable. */
CREATE OR ALTER VIEW assistant.vAnswerWithCitations
AS
SELECT turn.TurnID, session.UserID, turn.QuestionText, turn.AnswerText,
       citation.CitationID, citation.QuoteText, citation.PageNo,
       citation.StartOffset, citation.EndOffset, chunk.ChunkID,
       chunk.ContentID, chunk.Kind, chunk.Title,
       access.AuthorUserID, access.CommunityID
FROM assistant.RagTurn AS turn
JOIN assistant.RagSession AS session ON session.SessionID = turn.SessionID
JOIN assistant.RetrievalRun AS run ON run.TurnID = turn.TurnID
JOIN assistant.AnswerCitation AS citation ON citation.RetrievalRunID = run.RetrievalRunID
JOIN knowledge.vCurrentRagChunks AS chunk ON chunk.ChunkID = citation.ChunkID
JOIN social.vAccessibleContent AS access
  ON access.UserID = session.UserID AND access.ContentID = chunk.ContentID
WHERE NOT EXISTS
(
    /* A stored answer can use every retrieved chunk, not just cited chunks. */
    SELECT 1
    FROM assistant.RetrievedChunk AS usedChunk
    LEFT JOIN knowledge.vCurrentRagChunks AS currentChunk
      ON currentChunk.ChunkID = usedChunk.ChunkID
    LEFT JOIN social.vAccessibleContent AS currentAccess
      ON currentAccess.UserID = session.UserID
     AND currentAccess.ContentID = currentChunk.ContentID
    WHERE usedChunk.RetrievalRunID = run.RetrievalRunID
      AND currentAccess.ContentID IS NULL
);
GO

/* Filtering at read time makes a revoked item disappear immediately. */
CREATE OR ALTER VIEW assistant.vRecommendationFeed
AS
SELECT batch.UserID, batch.BatchID, item.ContentID, item.Rank,
       item.Score, item.ReasonCode, item.ReasonText,
       access.Kind, access.CommunityID, access.AuthorUserID
FROM assistant.RecommendationBatch AS batch
JOIN assistant.RecommendationItem AS item ON item.BatchID = batch.BatchID
JOIN social.vAccessibleContent AS access
  ON access.UserID = batch.UserID AND access.ContentID = item.ContentID
WHERE access.Kind IN ('POST', 'DOCUMENT');
GO
