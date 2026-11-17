/* The only two graph tables. Business identities remain relational. */
IF OBJECT_ID(N'social.UserNode', N'U') IS NULL
BEGIN
    CREATE TABLE social.UserNode
    (
        UserID bigint NOT NULL CONSTRAINT PK_UserNode PRIMARY KEY,
        CONSTRAINT FK_UserNode_User FOREIGN KEY (UserID) REFERENCES auth.UserAccount(UserID)
    ) AS NODE;
END;
GO
IF OBJECT_ID(N'social.Follows', N'U') IS NULL
BEGIN
    CREATE TABLE social.Follows
    (
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_Follows_CreatedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT EC_Follows_User_User CONNECTION (social.UserNode TO social.UserNode)
    ) AS EDGE;
END;
GO
/* All SQL-created accounts, including Firebase identities, receive their graph node. */
CREATE OR ALTER TRIGGER auth.trg_UserAccount_CreateNode
ON auth.UserAccount AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO social.UserNode(UserID) SELECT UserID FROM inserted;
END;
GO
CREATE OR ALTER TRIGGER social.trg_Follows_NoSelf
ON social.Follows AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM social.Follows WHERE $from_id = $to_id)
        THROW 51017, N'A user cannot follow themself.', 1;
END;
GO
