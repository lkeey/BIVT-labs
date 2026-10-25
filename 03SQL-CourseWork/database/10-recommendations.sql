/* Rule-based feed with five configurable, normalized signals. */
CREATE OR ALTER PROCEDURE assistant.usp_GenerateRecommendations
    @UserID bigint,
    @Limit int = 20,
    @TopicWeight decimal(4,3) = 0.300,
    @FollowWeight decimal(4,3) = 0.250,
    @MemberWeight decimal(4,3) = 0.200,
    @InterestWeight decimal(4,3) = 0.150,
    @FreshWeight decimal(4,3) = 0.100
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @Limit IS NULL OR @Limit NOT BETWEEN 1 AND 50
        THROW 51030, N'Limit must be between 1 and 50.', 1;
    IF @TopicWeight IS NULL OR @FollowWeight IS NULL OR @MemberWeight IS NULL
       OR @InterestWeight IS NULL OR @FreshWeight IS NULL
       OR @TopicWeight < 0 OR @FollowWeight < 0 OR @MemberWeight < 0
       OR @InterestWeight < 0 OR @FreshWeight < 0
       OR @TopicWeight+@FollowWeight+@MemberWeight+@InterestWeight+@FreshWeight <> 1
        THROW 51031, N'Recommendation weights must be nonnegative and sum to 1.', 1;
    IF NOT EXISTS (SELECT 1 FROM auth.UserAccount
                   WHERE UserID=@UserID AND AccountStatus='ACTIVE')
        THROW 51032, N'Active user is required.', 1;

    ;WITH Followed AS
    (
        SELECT DISTINCT followed.UserID
        FROM auth.UserAccount AS reader,
             social.Follows AS follows,
             auth.UserAccount AS followed
        WHERE MATCH(reader-(follows)->followed)
          AND reader.UserID=@UserID
    ),
    Joined AS
    (
        SELECT DISTINCT community.CommunityID
        FROM auth.UserAccount AS reader,
             social.MemberOf AS membership,
             social.Community AS community
        WHERE MATCH(reader-(membership)->community)
          AND reader.UserID=@UserID AND membership.MemberStatus='ACTIVE'
        UNION
        SELECT CommunityID FROM social.Community
        WHERE OwnerUserID=@UserID AND Status='ACTIVE'
    ),
    Reacted AS
    (
        SELECT DISTINCT reacted.ContentID
        FROM auth.UserAccount AS reader,
             social.ReactTo AS reaction,
             social.ContentItem AS reacted
        WHERE MATCH(reader-(reaction)->reacted) AND reader.UserID=@UserID
    ),
    Commented AS
    (
        SELECT DISTINCT post.ContentID
        FROM auth.UserAccount AS reader,
             social.Authored AS authored,
             social.ContentItem AS comment,
             social.CommentOn AS commentOn,
             social.ContentItem AS post
        WHERE MATCH(reader-(authored)->comment)
          AND MATCH(comment-(commentOn)->post)
          AND reader.UserID=@UserID AND comment.Kind='COMMENT'
    ),
    InterestContent AS
    (
        SELECT ContentID FROM Reacted
        UNION
        SELECT ContentID FROM Commented
    ),
    InterestCommunity AS
    (
        SELECT DISTINCT access.CommunityID
        FROM InterestContent AS interested
        JOIN social.vAccessibleContent AS access
          ON access.ContentID=interested.ContentID AND access.UserID=@UserID
    ),
    InterestEntity AS
    (
        SELECT DISTINCT entity.EntityName
        FROM knowledge.Chunk AS chunk,
             knowledge.Mentions AS mention,
             knowledge.KnowledgeEntity AS entity,
             knowledge.vCurrentRagChunks AS currentChunk,
             InterestContent AS interested
        WHERE MATCH(chunk-(mention)->entity)
          AND mention.EvidenceChunkID=chunk.ChunkID
          AND currentChunk.ChunkID=chunk.ChunkID
          AND interested.ContentID=currentChunk.ContentID
          AND EXISTS
              (SELECT 1 FROM social.vAccessibleContent AS access
               WHERE access.ContentID=interested.ContentID
                 AND access.UserID=@UserID)
    ),
    CandidateEntity AS
    (
        SELECT DISTINCT item.ContentID,entity.EntityName
        FROM knowledge.Chunk AS chunk,
             knowledge.Mentions AS mention,
             knowledge.KnowledgeEntity AS entity,
             social.ContentItem AS item
        WHERE MATCH(chunk-(mention)->entity)
          AND chunk.SourceRevisionID IN
              (SELECT SourceRevisionID FROM knowledge.vCurrentRagChunks)
          AND EXISTS (SELECT 1 FROM knowledge.SourceRevision AS revision
                      WHERE revision.SourceRevisionID=chunk.SourceRevisionID
                        AND revision.ContentID=item.ContentID)
    ),
    CandidateTopic AS
    (
        SELECT candidate.ContentID,
               CAST(CASE WHEN COUNT(interested.EntityName)>0 THEN 1.0 ELSE 0.0 END AS float) AS TopicScore
        FROM CandidateEntity AS candidate
        LEFT JOIN InterestEntity AS interested
          ON interested.EntityName=candidate.EntityName
        GROUP BY candidate.ContentID
    ),
    Popularity AS
    (
        SELECT content.ContentID,COUNT_BIG(*) AS Reactions
        FROM auth.UserAccount AS reactor,
             social.ReactTo AS reaction,
             social.ContentItem AS content
        WHERE MATCH(reactor-(reaction)->content)
        GROUP BY content.ContentID
    ),
    Signals AS
    (
        SELECT access.ContentID,access.CommunityID,access.AuthorUserID,
               CAST(COALESCE(topic.TopicScore,0) AS float) AS TopicScore,
               CAST(CASE WHEN followed.UserID IS NULL THEN 0 ELSE 1 END AS float) AS FollowScore,
               CAST(CASE WHEN joined.CommunityID IS NULL THEN 0 ELSE 1 END AS float) AS MemberScore,
               CAST(CASE WHEN interestedCommunity.CommunityID IS NULL THEN 0 ELSE 1 END AS float) AS InterestScore,
               CAST(CASE WHEN access.PublishedAt >= DATEADD(day,-1,SYSUTCDATETIME()) THEN 1.0
                         WHEN access.PublishedAt >= DATEADD(day,-7,SYSUTCDATETIME()) THEN 0.7
                         WHEN access.PublishedAt >= DATEADD(day,-30,SYSUTCDATETIME()) THEN 0.3
                         ELSE 0.1 END AS float) AS FreshScore,
               CAST(CASE WHEN COALESCE(popularity.Reactions,0)>=5 THEN 1.0
                         ELSE COALESCE(popularity.Reactions,0)/5.0 END AS float) AS PopularScore
        FROM social.vAccessibleContent AS access
        LEFT JOIN Followed AS followed ON followed.UserID=access.AuthorUserID
        LEFT JOIN Joined AS joined ON joined.CommunityID=access.CommunityID
        LEFT JOIN InterestCommunity AS interestedCommunity
          ON interestedCommunity.CommunityID=access.CommunityID
        LEFT JOIN CandidateTopic AS topic ON topic.ContentID=access.ContentID
        LEFT JOIN Popularity AS popularity ON popularity.ContentID=access.ContentID
        WHERE access.UserID=@UserID
          AND access.Kind IN ('POST','DOCUMENT')
          AND access.AuthorUserID<>@UserID
    ),
    Scored AS
    (
        SELECT *,CAST
        (
            CASE WHEN EXISTS (SELECT 1 FROM InterestContent)
                       OR EXISTS (SELECT 1 FROM Followed)
                       OR EXISTS (SELECT 1 FROM Joined)
                 THEN @TopicWeight*TopicScore+@FollowWeight*FollowScore
                    +@MemberWeight*MemberScore+@InterestWeight*InterestScore
                    +@FreshWeight*FreshScore
                 ELSE 0.6*FreshScore+0.4*PopularScore
            END AS decimal(9,6)
        ) AS TotalScore
        FROM Signals
    ),
    Diverse AS
    (
        SELECT *,ROW_NUMBER() OVER
            (PARTITION BY AuthorUserID ORDER BY TotalScore DESC,ContentID) AS AuthorOrdinal,
            ROW_NUMBER() OVER
            (PARTITION BY CommunityID ORDER BY TotalScore DESC,ContentID) AS CommunityOrdinal
        FROM Scored
    )
    SELECT ContentID,CommunityID,AuthorUserID,TopicScore,FollowScore,
           MemberScore,InterestScore,FreshScore,PopularScore,TotalScore
    INTO #Candidates
    FROM Diverse
    WHERE AuthorOrdinal<=2 AND CommunityOrdinal<=3;

    DECLARE @BatchID bigint;
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO assistant.RecommendationBatch (UserID,AlgorithmVersion)
        VALUES (@UserID,N'rule-v1');
        SET @BatchID=CONVERT(bigint,SCOPE_IDENTITY());

        ;WITH Ranked AS
        (
            SELECT TOP (@Limit) *,
                   ROW_NUMBER() OVER (ORDER BY TotalScore DESC,ContentID) AS RecommendationRank
            FROM #Candidates
            ORDER BY TotalScore DESC,ContentID
        )
        INSERT INTO assistant.RecommendationItem
            (BatchID,ContentID,[Rank],Score,ReasonCode,ReasonText)
        SELECT @BatchID,ContentID,RecommendationRank,TotalScore,
               CASE WHEN TopicScore>0 THEN 'RELATED_TOPIC'
                    WHEN FollowScore>0 THEN 'FOLLOWED_AUTHOR'
                    WHEN MemberScore>0 THEN 'MEMBER_COMMUNITY'
                    WHEN InterestScore>0 THEN 'SIMILAR_INTEREST'
                    WHEN PopularScore>0 THEN 'POPULAR' ELSE 'FRESH' END,
               CASE WHEN TopicScore>0 THEN N'Похоже на интересующие вас темы'
                    WHEN FollowScore>0 THEN N'Автор, на которого вы подписаны'
                    WHEN MemberScore>0 THEN N'Из вашего сообщества'
                    WHEN InterestScore>0 THEN N'Похоже на материалы, с которыми вы взаимодействовали'
                    WHEN PopularScore>0 THEN N'Популярно в доступных вам сообществах'
                    ELSE N'Недавно опубликовано' END
        FROM Ranked;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT [Rank],ContentID,Kind,Score,ReasonCode,ReasonText,CommunityID,AuthorUserID
    FROM assistant.vRecommendationFeed
    WHERE BatchID=@BatchID AND UserID=@UserID
    ORDER BY [Rank];
END;
GO
