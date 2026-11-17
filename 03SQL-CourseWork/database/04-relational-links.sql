/* Many-to-many relational associations, with foreign keys. */
IF OBJECT_ID(N'social.MemberOf', N'U') IS NULL
BEGIN
    CREATE TABLE social.MemberOf
    (
        UserID bigint NOT NULL,
        CommunityID bigint NOT NULL,
        MembershipID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_MemberOf PRIMARY KEY,
        MemberStatus varchar(8) NOT NULL CONSTRAINT DF_MemberOf_Status DEFAULT ('PENDING'),
        [Role] varchar(10) NOT NULL CONSTRAINT DF_MemberOf_Role DEFAULT ('MEMBER'),
        JoinedAt datetime2(3) NOT NULL CONSTRAINT DF_MemberOf_JoinedAt DEFAULT (SYSUTCDATETIME()),
        EndedAt datetime2(3) NULL,
        CONSTRAINT CK_MemberOf_Status CHECK (MemberStatus IN ('PENDING','ACTIVE','BLOCKED','REJECTED','BANNED','LEFT')),
        CONSTRAINT CK_MemberOf_Role CHECK ([Role] IN ('OWNER','ADMIN','MODERATOR','MEMBER')),
        CONSTRAINT CK_MemberOf_Period CHECK (EndedAt IS NULL OR EndedAt >= JoinedAt),
        CONSTRAINT CK_MemberOf_Active CHECK (MemberStatus <> 'ACTIVE' OR EndedAt IS NULL),
        CONSTRAINT FK_MemberOf_User FOREIGN KEY (UserID) REFERENCES auth.UserAccount(UserID),
        CONSTRAINT FK_MemberOf_Community FOREIGN KEY (CommunityID) REFERENCES social.Community(CommunityID)
    );
END;
GO

IF OBJECT_ID(N'social.ReactTo', N'U') IS NULL
BEGIN
    CREATE TABLE social.ReactTo
    (
        UserID bigint NOT NULL,
        ContentID bigint NOT NULL,
        CONSTRAINT PK_ReactTo PRIMARY KEY (UserID,ContentID),
        ReactionType varchar(12) NOT NULL,
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_ReactTo_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT CK_ReactTo_Type CHECK (ReactionType IN ('LIKE','HELPFUL','INSIGHTFUL')),
        CONSTRAINT FK_ReactTo_User FOREIGN KEY (UserID) REFERENCES auth.UserAccount(UserID),
        CONSTRAINT FK_ReactTo_Content FOREIGN KEY (ContentID) REFERENCES social.ContentItem(ContentID)
    );
END;
GO
