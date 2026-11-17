/* Relational identities and canonical foreign keys. */
IF OBJECT_ID(N'auth.UserAccount', N'U') IS NULL
BEGIN
    CREATE TABLE auth.UserAccount
    (
        UserID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_UserAccount PRIMARY KEY,
        Login nvarchar(80) NOT NULL,
        EmailNormalized nvarchar(254) NOT NULL,
        PasswordHash varbinary(64) NULL,
        AccountStatus varchar(12) NOT NULL CONSTRAINT DF_UserAccount_Status DEFAULT ('ACTIVE'),
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_UserAccount_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt datetime2(3) NOT NULL CONSTRAINT DF_UserAccount_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_UserAccount_Login UNIQUE (Login),
        CONSTRAINT UQ_UserAccount_Email UNIQUE (EmailNormalized),
        CONSTRAINT CK_UserAccount_Status CHECK (AccountStatus IN ('ACTIVE','BLOCKED','DELETED'))
    );
END;
GO

IF OBJECT_ID(N'auth.UserProfile', N'U') IS NULL
BEGIN
    CREATE TABLE auth.UserProfile
    (
        UserID bigint NOT NULL CONSTRAINT PK_UserProfile PRIMARY KEY,
        DisplayName nvarchar(120) NOT NULL,
        Bio nvarchar(1000) NULL,
        ProfileVisibility varchar(8) NOT NULL CONSTRAINT DF_UserProfile_Visibility DEFAULT ('PUBLIC'),
        UpdatedAt datetime2(3) NOT NULL CONSTRAINT DF_UserProfile_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_UserProfile_Account FOREIGN KEY (UserID) REFERENCES auth.UserAccount(UserID),
        CONSTRAINT CK_UserProfile_Visibility CHECK (ProfileVisibility IN ('PUBLIC','PRIVATE'))
    );
END;
GO

IF OBJECT_ID(N'social.Community', N'U') IS NULL
BEGIN
    CREATE TABLE social.Community
    (
        CommunityID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Community PRIMARY KEY,
        OwnerUserID bigint NOT NULL,
        Slug nvarchar(100) NOT NULL,
        CommunityName nvarchar(160) NOT NULL,
        Description nvarchar(1000) NULL,
        Visibility varchar(8) NOT NULL CONSTRAINT DF_Community_Visibility DEFAULT ('PUBLIC'),
        Status varchar(12) NOT NULL CONSTRAINT DF_Community_Status DEFAULT ('ACTIVE'),
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_Community_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_Community_Owner FOREIGN KEY (OwnerUserID) REFERENCES auth.UserAccount(UserID),
        CONSTRAINT UQ_Community_Slug UNIQUE (Slug),
        CONSTRAINT CK_Community_Slug CHECK (Slug NOT LIKE N'%[^a-z0-9-]%' AND LEN(Slug) BETWEEN 3 AND 100),
        CONSTRAINT CK_Community_Visibility CHECK (Visibility IN ('PUBLIC','PRIVATE')),
        CONSTRAINT CK_Community_Status CHECK (Status IN ('ACTIVE','ARCHIVED'))
    );
END;
GO

/* A comment references a post in the same community through a composite FK. */
IF OBJECT_ID(N'social.ContentItem', N'U') IS NULL
BEGIN
    CREATE TABLE social.ContentItem
    (
        ContentID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ContentItem PRIMARY KEY,
        Kind varchar(8) NOT NULL,
        ContentStatus varchar(12) NOT NULL CONSTRAINT DF_ContentItem_Status DEFAULT ('DRAFT'),
        AuthorUserID bigint NOT NULL,
        CommunityID bigint NOT NULL,
        ParentPostID bigint NULL,
        ParentKind varchar(8) NULL,
        CONSTRAINT FK_ContentItem_Author FOREIGN KEY (AuthorUserID) REFERENCES auth.UserAccount(UserID),
        CONSTRAINT FK_ContentItem_Community FOREIGN KEY (CommunityID) REFERENCES social.Community(CommunityID),
        CONSTRAINT UQ_ContentItem_Parent UNIQUE (ContentID,CommunityID,Kind),
        CONSTRAINT FK_ContentItem_Parent FOREIGN KEY (ParentPostID,CommunityID,ParentKind)
            REFERENCES social.ContentItem(ContentID,CommunityID,Kind),
        CONSTRAINT CK_ContentItem_Parent CHECK
            ((Kind = 'COMMENT' AND ParentPostID IS NOT NULL AND ParentKind IS NOT NULL AND ParentKind = 'POST')
             OR (Kind <> 'COMMENT' AND ParentPostID IS NULL AND ParentKind IS NULL)),
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_ContentItem_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt datetime2(3) NOT NULL CONSTRAINT DF_ContentItem_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        PublishedAt datetime2(3) NULL,
        CONSTRAINT CK_ContentItem_Kind CHECK (Kind IN ('POST','COMMENT','DOCUMENT')),
        CONSTRAINT CK_ContentItem_Status CHECK (ContentStatus IN ('DRAFT','PUBLISHED','HIDDEN','DELETED')),
        CONSTRAINT CK_ContentItem_PublishedAt CHECK (ContentStatus <> 'PUBLISHED' OR PublishedAt IS NOT NULL)
    );
END;
GO
