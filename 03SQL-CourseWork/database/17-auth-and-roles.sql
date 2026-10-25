/* Firebase UID, not email, binds a verified external identity to a SQL user. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'auth.ExternalIdentity',N'U') IS NULL
BEGIN
    CREATE TABLE auth.ExternalIdentity
    (
        FirebaseUID nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL
            CONSTRAINT PK_ExternalIdentity PRIMARY KEY,
        UserID bigint NOT NULL
            CONSTRAINT UQ_ExternalIdentity_User UNIQUE,
        CreatedAt datetime2(3) NOT NULL
            CONSTRAINT DF_ExternalIdentity_CreatedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_ExternalIdentity_User
            FOREIGN KEY (UserID) REFERENCES auth.UserAccount(UserID),
        CONSTRAINT CK_ExternalIdentity_UID CHECK
            (LEN(FirebaseUID) BETWEEN 1 AND 128)
    );
END;
GO

/* Call only after Firebase Admin verifies signature, issuer, audience and expiry. */
CREATE OR ALTER PROCEDURE auth.usp_GetOrCreateFirebaseUser
    @FirebaseUID nvarchar(128),
    @Email nvarchar(254) = NULL,
    @DisplayName nvarchar(120) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @FirebaseUID IS NULL OR LEN(@FirebaseUID) NOT BETWEEN 1 AND 128
        THROW 51220, N'Verified Firebase UID is required.', 1;
    IF @DisplayName IS NOT NULL AND LEN(@DisplayName)>120
        THROW 51221, N'Display name is too long.', 1;

    /* Provider email may change or be unverified, so it never merges accounts. */
    DECLARE @Hash varchar(64)=CONVERT(varchar(64),
        HASHBYTES('SHA2_256',CONVERT(varbinary(max),@FirebaseUID)),2);
    DECLARE @UserID bigint, @Status varchar(12);
    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT @UserID=UserID
        FROM auth.ExternalIdentity WITH (UPDLOCK,HOLDLOCK)
        WHERE FirebaseUID=@FirebaseUID;
        IF @UserID IS NULL
        BEGIN
            INSERT INTO auth.UserAccount(Login,EmailNormalized,AccountStatus)
            VALUES (CONCAT(N'fb-',@Hash),
                    CONCAT(N'fb-',@Hash,N'@identity.invalid'),'ACTIVE');
            SET @UserID=CONVERT(bigint,SCOPE_IDENTITY());
            INSERT INTO auth.UserProfile(UserID,DisplayName,ProfileVisibility)
            VALUES (@UserID,
                    COALESCE(NULLIF(LTRIM(RTRIM(@DisplayName)),N''),
                             CONCAT(N'Пользователь ',LEFT(@Hash,8))),
                    'PUBLIC');
            INSERT INTO auth.ExternalIdentity(FirebaseUID,UserID)
            VALUES (@FirebaseUID,@UserID);
        END;
        SELECT @Status=AccountStatus
        FROM auth.UserAccount WITH (UPDLOCK,HOLDLOCK)
        WHERE UserID=@UserID;
        IF @Status <> 'ACTIVE'
            THROW 51222, N'Account is not active.', 1;
        COMMIT TRANSACTION;
        SELECT @UserID AS UserID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* Assign database users to these roles manually. Neither role has table DML. */
IF DATABASE_PRINCIPAL_ID(N'coursework_api') IS NULL
    CREATE ROLE coursework_api AUTHORIZATION dbo;
GO
IF DATABASE_PRINCIPAL_ID(N'coursework_worker') IS NULL
    CREATE ROLE coursework_worker AUTHORIZATION dbo;
GO

GRANT EXECUTE ON OBJECT::auth.usp_GetOrCreateFirebaseUser TO coursework_api;
GRANT EXECUTE ON OBJECT::auth.usp_GetUserProfile TO coursework_api;
GRANT EXECUTE ON OBJECT::social.usp_ListCommunities TO coursework_api;
GRANT EXECUTE ON OBJECT::social.usp_GetCommunity TO coursework_api;
GRANT EXECUTE ON OBJECT::social.usp_CreateCommunity TO coursework_api;
GRANT EXECUTE ON OBJECT::social.usp_RequestMembership TO coursework_api;
GRANT EXECUTE ON OBJECT::social.usp_SetMembership TO coursework_api;
GRANT EXECUTE ON OBJECT::social.usp_LeaveCommunity TO coursework_api;
GRANT EXECUTE ON OBJECT::social.usp_ListPendingMemberships TO coursework_api;
GRANT EXECUTE ON OBJECT::social.usp_SetFollow TO coursework_api;
GRANT EXECUTE ON OBJECT::social.usp_SetReaction TO coursework_api;
GRANT EXECUTE ON OBJECT::social.usp_ModerateContent TO coursework_api;
GRANT EXECUTE ON OBJECT::social.usp_PublishContent TO coursework_api;
GRANT EXECUTE ON OBJECT::social.usp_ListPosts TO coursework_api;
GRANT EXECUTE ON OBJECT::social.usp_GetPost TO coursework_api;
GRANT EXECUTE ON OBJECT::social.usp_ListComments TO coursework_api;
GRANT EXECUTE ON OBJECT::social.usp_GetComment TO coursework_api;
GRANT EXECUTE ON OBJECT::knowledge.usp_SaveDocumentVersion TO coursework_api;
GRANT EXECUTE ON OBJECT::knowledge.usp_ListDocuments TO coursework_api;
GRANT EXECUTE ON OBJECT::knowledge.usp_GetDocument TO coursework_api;
GRANT EXECUTE ON OBJECT::knowledge.usp_GetDocumentFile TO coursework_api;
GRANT EXECUTE ON OBJECT::assistant.usp_StartRagSession TO coursework_api;
GRANT EXECUTE ON OBJECT::assistant.usp_StartRagTurn TO coursework_api;
GRANT EXECUTE ON OBJECT::assistant.usp_SearchRag TO coursework_api;
GRANT EXECUTE ON OBJECT::assistant.usp_RecordRetrievedChunks TO coursework_api;
GRANT EXECUTE ON OBJECT::assistant.usp_SaveRagAnswer TO coursework_api;
GRANT EXECUTE ON OBJECT::assistant.usp_SaveRagNoSources TO coursework_api;
GRANT EXECUTE ON OBJECT::assistant.usp_FailRagTurn TO coursework_api;
GRANT EXECUTE ON OBJECT::assistant.usp_GetRagTurn TO coursework_api;
GRANT EXECUTE ON OBJECT::assistant.usp_GenerateRecommendations TO coursework_api;
GRANT EXECUTE ON OBJECT::assistant.usp_RevokeContentAccess TO coursework_api;
GO

GRANT EXECUTE ON OBJECT::ops.usp_ClaimIndexOutbox TO coursework_worker;
GRANT EXECUTE ON OBJECT::ops.usp_GetClaimedIndexSource TO coursework_worker;
GRANT EXECUTE ON OBJECT::ops.usp_RenewIndexLease TO coursework_worker;
GRANT EXECUTE ON OBJECT::ops.usp_RequeueExpiredIndexOutbox TO coursework_worker;
GRANT EXECUTE ON OBJECT::ops.usp_CommitIndexResult TO coursework_worker;
GRANT EXECUTE ON OBJECT::ops.usp_CommitIndexDeletion TO coursework_worker;
GRANT EXECUTE ON OBJECT::ops.usp_CompleteIndexOutbox TO coursework_worker;
GO
