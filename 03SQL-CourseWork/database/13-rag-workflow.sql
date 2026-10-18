/*
 * RAG lifecycle for a trusted server-side caller. @UserID must come from the
 * authenticated backend session; these procedures do not authenticate a user.
 * The search result is a candidate set. Only chunks rechecked below may be
 * recorded as context supplied to the answer generator.
 */
CREATE OR ALTER PROCEDURE assistant.usp_StartRagSession
    @UserID bigint,
    @CommunityID bigint = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS
       (SELECT 1 FROM auth.UserAccount
        WHERE UserID = @UserID AND AccountStatus = 'ACTIVE')
        THROW 51050, N'An active user is required to start a RAG session.', 1;
    IF @CommunityID IS NOT NULL AND NOT EXISTS
       (SELECT 1 FROM auth.fn_UserCanReadCommunity(@UserID, @CommunityID))
        THROW 51051, N'The selected community is not accessible.', 1;

    INSERT INTO assistant.RagSession (UserID, Scope, CommunityID)
    VALUES (@UserID,
            CASE WHEN @CommunityID IS NULL THEN 'AllAccessible' ELSE 'Community' END,
            @CommunityID);

    SELECT CONVERT(bigint, SCOPE_IDENTITY()) AS SessionID;
END;
GO

/* Serializing on the session row makes TurnNo monotonic within each session. */
CREATE OR ALTER PROCEDURE assistant.usp_StartRagTurn
    @SessionID bigint,
    @UserID bigint,
    @Question nvarchar(2000),
    @ModelVersion nvarchar(120),
    @RetrievalMode varchar(16) = 'HYBRID_GRAPH',
    @AccessPolicyVersion nvarchar(40) = N'1'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@Question)), N'') IS NULL
       OR NULLIF(LTRIM(RTRIM(@ModelVersion)), N'') IS NULL
       OR NULLIF(LTRIM(RTRIM(@AccessPolicyVersion)), N'') IS NULL
       OR @RetrievalMode IS NULL
       OR @RetrievalMode NOT IN ('HYBRID_GRAPH', 'VECTOR', 'FULLTEXT')
        THROW 51052, N'Question or retrieval settings are invalid.', 1;

    DECLARE @OwnerUserID bigint, @CommunityID bigint, @NextTurnNo int;
    DECLARE @TurnID bigint, @RetrievalRunID bigint;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @OwnerUserID = session.UserID,
               @CommunityID = session.CommunityID
        FROM assistant.RagSession AS session WITH (UPDLOCK, HOLDLOCK)
        WHERE session.SessionID = @SessionID;

        IF @OwnerUserID IS NULL OR @OwnerUserID <> @UserID
            THROW 51053, N'RAG session does not belong to this user.', 1;
        IF NOT EXISTS
           (SELECT 1 FROM auth.UserAccount
            WHERE UserID = @UserID AND AccountStatus = 'ACTIVE')
            THROW 51054, N'RAG session user is no longer active.', 1;
        IF @CommunityID IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM auth.fn_UserCanReadCommunity(@UserID, @CommunityID))
            THROW 51055, N'RAG session community is no longer accessible.', 1;

        SELECT @NextTurnNo = ISNULL(MAX(TurnNo), 0) + 1
        FROM assistant.RagTurn
        WHERE SessionID = @SessionID;

        INSERT INTO assistant.RagTurn (SessionID, TurnNo, QuestionText)
        VALUES (@SessionID, @NextTurnNo, @Question);
        SET @TurnID = CONVERT(bigint, SCOPE_IDENTITY());

        INSERT INTO assistant.RetrievalRun
            (TurnID, RetrievalMode, AccessPolicyVersion, ModelVersion)
        VALUES (@TurnID, @RetrievalMode, @AccessPolicyVersion, @ModelVersion);
        SET @RetrievalRunID = CONVERT(bigint, SCOPE_IDENTITY());

        COMMIT TRANSACTION;
        SELECT @TurnID AS TurnID, @RetrievalRunID AS RetrievalRunID,
               @NextTurnNo AS TurnNo, @CommunityID AS CommunityID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/*
 * The backend passes the exact ordered set it will send to the LLM. SQL derives
 * snippets from current source text, rather than accepting caller-supplied text.
 * The result may be recorded once while the turn is pending. Empty retrievals
 * use assistant.usp_SaveRagNoSources from script 09 instead of calling this.
 */
CREATE OR ALTER PROCEDURE assistant.usp_RecordRetrievedChunks
    @RetrievalRunID bigint,
    @UserID bigint,
    @ChunksJson nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ChunksJson IS NULL OR ISJSON(@ChunksJson, ARRAY) <> 1
        THROW 51056, N'Retrieved chunks must be a JSON array.', 1;

    DECLARE @Input TABLE
    (
        ChunkID bigint NULL,
        [Rank] int NULL,
        VectorScore decimal(9,6) NULL,
        TextScore decimal(9,6) NULL,
        GraphScore decimal(9,6) NULL
    );
    INSERT INTO @Input (ChunkID, [Rank], VectorScore, TextScore, GraphScore)
    SELECT ChunkID, [Rank], VectorScore, TextScore, GraphScore
    FROM OPENJSON(@ChunksJson)
    WITH
    (
        ChunkID bigint '$.chunk_id',
        [Rank] int '$.rank',
        VectorScore decimal(9,6) '$.vector_score',
        TextScore decimal(9,6) '$.text_score',
        GraphScore decimal(9,6) '$.graph_score'
    );

    DECLARE @InputCount int = (SELECT COUNT(*) FROM @Input);
    IF @InputCount NOT BETWEEN 1 AND 20
       OR EXISTS
          (SELECT 1 FROM @Input
           WHERE ChunkID IS NULL OR [Rank] IS NULL OR [Rank] < 1
              OR VectorScore IS NULL OR VectorScore NOT BETWEEN -1 AND 1
              OR TextScore IS NULL OR TextScore NOT BETWEEN 0 AND 1
              OR GraphScore IS NULL OR GraphScore NOT BETWEEN 0 AND 1)
       OR EXISTS (SELECT 1 FROM @Input GROUP BY ChunkID HAVING COUNT(*) > 1)
       OR EXISTS (SELECT 1 FROM @Input GROUP BY [Rank] HAVING COUNT(*) > 1)
       OR (SELECT MIN([Rank]) FROM @Input) <> 1
       OR (SELECT MAX([Rank]) FROM @Input) <> @InputCount
        THROW 51057, N'Retrieved chunks must have unique IDs, consecutive ranks and valid scores.', 1;

    DECLARE @OwnerUserID bigint, @CommunityID bigint, @TurnStatus varchar(12);
    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @OwnerUserID = session.UserID,
               @CommunityID = session.CommunityID,
               @TurnStatus = turn.GenerationStatus
        FROM assistant.RetrievalRun AS run WITH (UPDLOCK, HOLDLOCK)
        JOIN assistant.RagTurn AS turn WITH (UPDLOCK, HOLDLOCK)
          ON turn.TurnID = run.TurnID
        JOIN assistant.RagSession AS session
          ON session.SessionID = turn.SessionID
        WHERE run.RetrievalRunID = @RetrievalRunID;

        IF @OwnerUserID IS NULL OR @OwnerUserID <> @UserID
            THROW 51058, N'Retrieval run does not belong to this user.', 1;
        IF @TurnStatus <> 'PENDING'
            THROW 51059, N'Only a pending RAG turn may record retrieved chunks.', 1;
        IF NOT EXISTS
           (SELECT 1 FROM auth.UserAccount
            WHERE UserID = @UserID AND AccountStatus = 'ACTIVE')
            THROW 51060, N'Retrieval user is no longer active.', 1;
        IF @CommunityID IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM auth.fn_UserCanReadCommunity(@UserID, @CommunityID))
            THROW 51061, N'Retrieval community is no longer accessible.', 1;
        IF EXISTS
           (SELECT 1 FROM assistant.RetrievedChunk
            WHERE RetrievalRunID = @RetrievalRunID)
            THROW 51062, N'Retrieval run already has recorded chunks.', 1;

        INSERT INTO assistant.RetrievedChunk
            (RetrievalRunID, ChunkID, [Rank], VectorScore,
             TextScore, GraphScore, Snippet)
        SELECT @RetrievalRunID, input.ChunkID, input.[Rank],
               input.VectorScore, input.TextScore, input.GraphScore,
               LEFT(currentChunk.ChunkText, 1000)
        FROM @Input AS input
        JOIN knowledge.vCurrentRagChunks AS currentChunk
          ON currentChunk.ChunkID = input.ChunkID
        WHERE EXISTS
        (
            SELECT 1
            FROM social.vAccessibleContent AS access
            WHERE access.UserID = @UserID
              AND access.ContentID = currentChunk.ContentID
              AND (@CommunityID IS NULL OR access.CommunityID = @CommunityID)
        );

        IF @@ROWCOUNT <> @InputCount
            THROW 51063, N'A retrieved chunk is stale or outside the current access scope.', 1;

        COMMIT TRANSACTION;
        SELECT @RetrievalRunID AS RetrievalRunID, @InputCount AS RecordedChunkCount;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
