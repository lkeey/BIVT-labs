/* Immutable revisions preserve history; filtered indexes in 06 allow one current revision. */
IF OBJECT_ID(N'social.PostRevision', N'U') IS NULL
BEGIN
    CREATE TABLE social.PostRevision
    (
        RevisionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_PostRevision PRIMARY KEY,
        ContentID bigint NOT NULL,
        RevisionNo int NOT NULL,
        Body nvarchar(max) NOT NULL,
        ContentHash binary(32) NOT NULL,
        EditedByUserID bigint NOT NULL,
        IsCurrent bit NOT NULL CONSTRAINT DF_PostRevision_Current DEFAULT (1),
        ChangedAt datetime2(3) NOT NULL CONSTRAINT DF_PostRevision_ChangedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_PostRevision_Content FOREIGN KEY (ContentID) REFERENCES social.ContentItem(ContentID),
        CONSTRAINT FK_PostRevision_Editor FOREIGN KEY (EditedByUserID) REFERENCES auth.UserAccount(UserID),
        CONSTRAINT UQ_PostRevision_Number UNIQUE (ContentID, RevisionNo),
        CONSTRAINT UQ_PostRevision_ContentRevision UNIQUE (ContentID, RevisionID),
        CONSTRAINT CK_PostRevision_Number CHECK (RevisionNo > 0),
        CONSTRAINT CK_PostRevision_Body CHECK (DATALENGTH(Body) > 0)
    );
END;
GO

IF OBJECT_ID(N'social.CommentRevision', N'U') IS NULL
BEGIN
    CREATE TABLE social.CommentRevision
    (
        RevisionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_CommentRevision PRIMARY KEY,
        ContentID bigint NOT NULL,
        RevisionNo int NOT NULL,
        Body nvarchar(max) NOT NULL,
        CommentStatus varchar(8) NOT NULL CONSTRAINT DF_CommentRevision_Status DEFAULT ('VISIBLE'),
        IsCurrent bit NOT NULL CONSTRAINT DF_CommentRevision_Current DEFAULT (1),
        ChangedAt datetime2(3) NOT NULL CONSTRAINT DF_CommentRevision_ChangedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_CommentRevision_Content FOREIGN KEY (ContentID) REFERENCES social.ContentItem(ContentID),
        CONSTRAINT UQ_CommentRevision_Number UNIQUE (ContentID, RevisionNo),
        CONSTRAINT UQ_CommentRevision_ContentRevision UNIQUE (ContentID, RevisionID),
        CONSTRAINT CK_CommentRevision_Number CHECK (RevisionNo > 0),
        CONSTRAINT CK_CommentRevision_Body CHECK (DATALENGTH(Body) > 0),
        CONSTRAINT CK_CommentRevision_Status CHECK (CommentStatus IN ('VISIBLE','HIDDEN','DELETED'))
    );
END;
GO

IF OBJECT_ID(N'social.DocumentDetail', N'U') IS NULL
BEGIN
    CREATE TABLE social.DocumentDetail
    (
        ContentID bigint NOT NULL CONSTRAINT PK_DocumentDetail PRIMARY KEY,
        Title nvarchar(250) NOT NULL,
        Description nvarchar(2000) NULL,
        DocumentStatus varchar(12) NOT NULL CONSTRAINT DF_DocumentDetail_Status DEFAULT ('READY'),
        CONSTRAINT FK_DocumentDetail_Content FOREIGN KEY (ContentID) REFERENCES social.ContentItem(ContentID),
        CONSTRAINT CK_DocumentDetail_Status CHECK (DocumentStatus = 'READY')
    );
END;
GO

/* Both uploaded files and directly entered Russian text are supported. */
IF OBJECT_ID(N'social.DocumentVersion', N'U') IS NULL
BEGIN
    CREATE TABLE social.DocumentVersion
    (
        DocumentVersionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_DocumentVersion PRIMARY KEY,
        ContentID bigint NOT NULL,
        VersionNo int NOT NULL,
        FileName nvarchar(260) NULL,
        MimeType varchar(127) NOT NULL,
        FileBytes varbinary(max) NULL,
        PlainText nvarchar(max) NULL,
        SizeBytes bigint NOT NULL,
        SHA256 binary(32) NOT NULL,
        IsCurrent bit NOT NULL CONSTRAINT DF_DocumentVersion_Current DEFAULT (1),
        UploadStatus varchar(8) NOT NULL CONSTRAINT DF_DocumentVersion_UploadStatus DEFAULT ('STORED'),
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_DocumentVersion_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_DocumentVersion_Content FOREIGN KEY (ContentID) REFERENCES social.DocumentDetail(ContentID),
        CONSTRAINT UQ_DocumentVersion_Number UNIQUE (ContentID, VersionNo),
        CONSTRAINT UQ_DocumentVersion_ContentVersion UNIQUE (ContentID, DocumentVersionID),
        CONSTRAINT CK_DocumentVersion_Number CHECK (VersionNo > 0),
        CONSTRAINT CK_DocumentVersion_MimeType CHECK (MimeType IN
            ('text/plain','application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document')),
        CONSTRAINT CK_DocumentVersion_Payload CHECK
            ((MimeType = 'text/plain' AND PlainText IS NOT NULL AND FileBytes IS NULL)
             OR (MimeType <> 'text/plain' AND FileBytes IS NOT NULL AND PlainText IS NULL AND FileName IS NOT NULL)),
        CONSTRAINT CK_DocumentVersion_Size CHECK
            (SizeBytes BETWEEN 1 AND 10485760
             AND SizeBytes = COALESCE(DATALENGTH(FileBytes),DATALENGTH(PlainText))),
        CONSTRAINT CK_DocumentVersion_UploadStatus CHECK (UploadStatus IN ('STORED','FAILED'))
    );
END;
GO
