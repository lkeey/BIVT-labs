/* Canonical social and publication relationships. All endpoints are constrained. */
IF OBJECT_ID(N'social.Follows', N'U') IS NULL
BEGIN
    CREATE TABLE social.Follows
    (
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_Follows_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT EC_Follows_User_User CONNECTION (auth.UserAccount TO auth.UserAccount)
    ) AS EDGE;
END;
GO

IF OBJECT_ID(N'social.MemberOf', N'U') IS NULL
BEGIN
    CREATE TABLE social.MemberOf
    (
        MembershipID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_MemberOf PRIMARY KEY,
        MemberStatus varchar(8) NOT NULL CONSTRAINT DF_MemberOf_Status DEFAULT ('PENDING'),
        [Role] varchar(10) NOT NULL CONSTRAINT DF_MemberOf_Role DEFAULT ('MEMBER'),
        JoinedAt datetime2(3) NOT NULL CONSTRAINT DF_MemberOf_JoinedAt DEFAULT (SYSUTCDATETIME()),
        EndedAt datetime2(3) NULL,
        CONSTRAINT CK_MemberOf_Status CHECK (MemberStatus IN ('PENDING','ACTIVE','REJECTED','BANNED','LEFT')),
        CONSTRAINT CK_MemberOf_Role CHECK ([Role] IN ('OWNER','MODERATOR','MEMBER')),
        CONSTRAINT CK_MemberOf_Period CHECK (EndedAt IS NULL OR EndedAt >= JoinedAt),
        CONSTRAINT CK_MemberOf_Active CHECK (MemberStatus <> 'ACTIVE' OR EndedAt IS NULL),
        CONSTRAINT EC_MemberOf_User_Community CONNECTION (auth.UserAccount TO social.Community)
    ) AS EDGE;
END;
GO

IF OBJECT_ID(N'social.Authored', N'U') IS NULL
BEGIN
    CREATE TABLE social.Authored
    (
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_Authored_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT EC_Authored_User_Content CONNECTION (auth.UserAccount TO social.ContentItem)
    ) AS EDGE;
END;
GO

IF OBJECT_ID(N'social.PublishedIn', N'U') IS NULL
BEGIN
    CREATE TABLE social.PublishedIn
    (
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_PublishedIn_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT EC_PublishedIn_Content_Community CONNECTION (social.ContentItem TO social.Community)
    ) AS EDGE;
END;
GO

IF OBJECT_ID(N'social.CommentOn', N'U') IS NULL
BEGIN
    CREATE TABLE social.CommentOn
    (
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_CommentOn_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT EC_CommentOn_Content_Content CONNECTION (social.ContentItem TO social.ContentItem)
    ) AS EDGE;
END;
GO

IF OBJECT_ID(N'social.ReactTo', N'U') IS NULL
BEGIN
    CREATE TABLE social.ReactTo
    (
        ReactionType varchar(12) NOT NULL,
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_ReactTo_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT CK_ReactTo_Type CHECK (ReactionType IN ('LIKE','HELPFUL','INSIGHTFUL')),
        CONSTRAINT EC_ReactTo_User_Content CONNECTION (auth.UserAccount TO social.ContentItem)
    ) AS EDGE;
END;
GO
