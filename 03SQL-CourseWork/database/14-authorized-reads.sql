/*
 * Read operations for a trusted HTTP backend. The caller supplies @UserID from
 * its authenticated session. These procedures do not authenticate a SQL caller.
 */
CREATE OR ALTER PROCEDURE knowledge.usp_GetDocumentFile
    @UserID bigint,
    @ContentID bigint
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    /* The original is downloadable only after the current version is READY. */
    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT version.DocumentVersionID, version.FileName, version.MimeType,
               version.SizeBytes, version.SHA256, version.FileBytes,
               version.PlainText
        FROM social.vAccessibleContent AS access
        JOIN social.DocumentDetail AS document
          ON document.ContentID = access.ContentID
        JOIN knowledge.DocumentVersion AS version
          ON version.ContentID = document.ContentID AND version.IsCurrent = 1
        WHERE access.UserID = @UserID
          AND access.ContentID = @ContentID
          AND access.Kind = 'DOCUMENT'
          AND document.DocumentStatus = 'READY'
          AND (version.FileBytes IS NOT NULL OR version.PlainText IS NOT NULL);

        IF @@ROWCOUNT <> 1
            THROW 51070, N'Current document file is unavailable.', 1;
        COMMIT TRANSACTION;
        SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
        THROW;
    END CATCH;
END;
GO

/* Pending applicants are visible only to the community owner or an active admin. */
CREATE OR ALTER PROCEDURE social.usp_ListPendingMemberships
    @ActorUserID bigint,
    @CommunityID bigint,
    @AfterMembershipID bigint = NULL,
    @Limit int = 50
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @Limit IS NULL OR @Limit NOT BETWEEN 1 AND 100
       OR (@AfterMembershipID IS NOT NULL AND @AfterMembershipID < 0)
        THROW 51072, N'Invalid membership page request.', 1;

    DECLARE @OwnerUserID bigint, @ActorRole varchar(10),
            @LockResult int, @LockResource nvarchar(255) =
                CONCAT(N'social:community:', @CommunityID, N':membership');
    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = 'Shared', @LockOwner = 'Transaction', @LockTimeout = 10000;
        IF @LockResult < 0
            THROW 51073, N'Could not lock community membership.', 1;

        SELECT @OwnerUserID = OwnerUserID
        FROM social.Community
        WHERE CommunityID = @CommunityID AND Status = 'ACTIVE';
        IF @OwnerUserID IS NULL OR NOT EXISTS
           (SELECT 1 FROM auth.UserAccount
            WHERE UserID = @ActorUserID AND AccountStatus = 'ACTIVE')
            THROW 51074, N'Community membership list is unavailable.', 1;

        IF @ActorUserID = @OwnerUserID SET @ActorRole = 'OWNER';
        ELSE
            SELECT @ActorRole = edge.[Role]
            FROM auth.UserAccount AS actor,
                 social.MemberOf AS edge,
                 social.Community AS community
            WHERE MATCH(actor-(edge)->community)
              AND actor.UserID = @ActorUserID
              AND community.CommunityID = @CommunityID
              AND edge.MemberStatus = 'ACTIVE' AND edge.EndedAt IS NULL
              AND edge.[Role] = 'ADMIN';
        IF @ActorRole IS NULL OR @ActorRole NOT IN ('OWNER','ADMIN')
            THROW 51074, N'Community membership list is unavailable.', 1;

        SELECT TOP (@Limit) edge.MembershipID, applicant.UserID,
               (SELECT profile.DisplayName FROM auth.UserProfile AS profile
                WHERE profile.UserID = applicant.UserID) AS DisplayName,
               edge.JoinedAt
        FROM auth.UserAccount AS applicant,
             social.MemberOf AS edge,
             social.Community AS community
        WHERE MATCH(applicant-(edge)->community)
          AND community.CommunityID = @CommunityID
          AND edge.MemberStatus = 'PENDING' AND edge.EndedAt IS NULL
          AND edge.MembershipID > ISNULL(@AfterMembershipID, 0)
        ORDER BY edge.MembershipID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/*
 * A stored answer is delivered only while every retrieved source and every
 * citation remains current and readable. The first result set is the turn;
 * the second is its citations. REVOKED means the HTTP layer must return 410
 * without the saved answer text.
 */
CREATE OR ALTER PROCEDURE assistant.usp_GetRagTurn
    @UserID bigint,
    @TurnID bigint
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    DECLARE @StoredStatus varchar(12), @QuestionText nvarchar(2000),
            @AnswerText nvarchar(max),
            @AnswerModel nvarchar(120), @CompletedAt datetime2(3),
            @RetrievalRunID bigint, @ExpectedCitations int = 0,
            @VisibleCitations int = 0, @DeliveryStatus varchar(12);

    BEGIN TRY
    BEGIN TRANSACTION;
    SELECT @StoredStatus = turn.GenerationStatus,
           @QuestionText = turn.QuestionText,
           @AnswerText = turn.AnswerText,
           @AnswerModel = turn.AnswerModel,
           @CompletedAt = turn.CompletedAt
    FROM assistant.RagTurn AS turn
    JOIN assistant.RagSession AS session ON session.SessionID = turn.SessionID
    JOIN auth.UserAccount AS account ON account.UserID = session.UserID
    WHERE turn.TurnID = @TurnID AND session.UserID = @UserID
      AND account.AccountStatus = 'ACTIVE';

    IF @StoredStatus IS NULL
        THROW 51071, N'RAG turn is unavailable.', 1;

    SELECT TOP (1) @RetrievalRunID = run.RetrievalRunID
    FROM assistant.RetrievalRun AS run
    WHERE run.TurnID = @TurnID
    ORDER BY run.RetrievalRunID DESC;

    IF @StoredStatus = 'COMPLETED'
    BEGIN
        SELECT @ExpectedCitations = COUNT(*)
        FROM assistant.AnswerCitation
        WHERE RetrievalRunID = @RetrievalRunID;

        SELECT @VisibleCitations = COUNT(*)
        FROM assistant.AnswerCitation AS citation
        JOIN assistant.vAnswerWithCitations AS visible
          ON visible.CitationID = citation.CitationID
         AND visible.TurnID = @TurnID
         AND visible.UserID = @UserID
        WHERE citation.RetrievalRunID = @RetrievalRunID;
    END;

    SET @DeliveryStatus = CASE
        WHEN @StoredStatus = 'COMPLETED'
         AND (@ExpectedCitations = 0 OR @VisibleCitations <> @ExpectedCitations)
            THEN 'REVOKED'
        ELSE @StoredStatus
    END;

    SELECT @TurnID AS TurnID, @QuestionText AS QuestionText,
           @DeliveryStatus AS DeliveryStatus,
           CASE WHEN @DeliveryStatus IN ('COMPLETED', 'NO_SOURCES')
                THEN @AnswerText ELSE NULL END AS AnswerText,
           CASE WHEN @DeliveryStatus = 'COMPLETED'
                THEN @AnswerModel ELSE NULL END AS AnswerModel,
           @CompletedAt AS CompletedAt;

    SELECT visible.CitationID, visible.ChunkID, visible.ContentID,
           visible.Kind, visible.Title, visible.AuthorUserID,
           visible.CommunityID, visible.QuoteText, visible.PageNo,
           visible.StartOffset, visible.EndOffset
    FROM assistant.vAnswerWithCitations AS visible
    JOIN assistant.AnswerCitation AS citation
      ON citation.CitationID = visible.CitationID
     AND citation.RetrievalRunID = @RetrievalRunID
    WHERE visible.UserID = @UserID
      AND visible.TurnID = @TurnID
      AND @DeliveryStatus = 'COMPLETED'
    ORDER BY visible.CitationID;
    COMMIT TRANSACTION;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
        THROW;
    END CATCH;
END;
GO
