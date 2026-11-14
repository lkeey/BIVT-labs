/*
 * Read operations for a trusted HTTP backend. The caller supplies @UserID from
 * its authenticated session. These procedures do not authenticate a SQL caller.
 */
CREATE OR ALTER PROCEDURE social.usp_GetDocumentFile
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
        JOIN social.DocumentVersion AS version
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
            FROM auth.UserAccount AS actor
            JOIN social.MemberOf AS edge ON edge.UserID = actor.UserID
            JOIN social.Community AS community ON community.CommunityID = edge.CommunityID
            WHERE 1 = 1
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
        FROM auth.UserAccount AS applicant
            JOIN social.MemberOf AS edge ON edge.UserID = applicant.UserID
            JOIN social.Community AS community ON community.CommunityID = edge.CommunityID
            WHERE 1 = 1
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
