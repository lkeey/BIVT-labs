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
        DocumentStatus varchar(12) NOT NULL CONSTRAINT DF_DocumentDetail_Status DEFAULT ('PROCESSING'),
        CONSTRAINT FK_DocumentDetail_Content FOREIGN KEY (ContentID) REFERENCES social.ContentItem(ContentID),
        CONSTRAINT CK_DocumentDetail_Status CHECK (DocumentStatus IN ('PROCESSING','READY','FAILED'))
    );
END;
GO

/* Both uploaded files and directly entered Russian text are supported. */
IF OBJECT_ID(N'knowledge.DocumentVersion', N'U') IS NULL
BEGIN
    CREATE TABLE knowledge.DocumentVersion
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
        OCRStatus varchar(10) NOT NULL CONSTRAINT DF_DocumentVersion_OCRStatus DEFAULT ('PENDING'),
        OcrEngineVersion nvarchar(80) NULL,
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
        CONSTRAINT CK_DocumentVersion_UploadStatus CHECK (UploadStatus IN ('STORED','FAILED')),
        CONSTRAINT CK_DocumentVersion_OCRStatus CHECK (OCRStatus IN ('PENDING','COMPLETED','NOT_NEEDED','FAILED'))
    );
END;
GO

/* A source revision identifies exactly one source snapshot. Its text is a searchable projection. */
IF OBJECT_ID(N'knowledge.SourceRevision', N'U') IS NULL
BEGIN
    CREATE TABLE knowledge.SourceRevision
    (
        SourceRevisionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_SourceRevision PRIMARY KEY,
        ContentID bigint NOT NULL,
        PostRevisionID bigint NULL,
        CommentRevisionID bigint NULL,
        DocumentVersionID bigint NULL,
        IsCurrent bit NOT NULL CONSTRAINT DF_SourceRevision_Current DEFAULT (1),
        ProcessingStatus varchar(10) NOT NULL CONSTRAINT DF_SourceRevision_Status DEFAULT ('PENDING'),
        ExtractedText nvarchar(max) NULL,
        TextHash binary(32) NULL,
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_SourceRevision_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ProcessedAt datetime2(3) NULL,
        CONSTRAINT FK_SourceRevision_Content FOREIGN KEY (ContentID) REFERENCES social.ContentItem(ContentID),
        CONSTRAINT FK_SourceRevision_Post FOREIGN KEY (ContentID,PostRevisionID)
            REFERENCES social.PostRevision(ContentID,RevisionID),
        CONSTRAINT FK_SourceRevision_Comment FOREIGN KEY (ContentID,CommentRevisionID)
            REFERENCES social.CommentRevision(ContentID,RevisionID),
        CONSTRAINT FK_SourceRevision_Document FOREIGN KEY (ContentID,DocumentVersionID)
            REFERENCES knowledge.DocumentVersion(ContentID,DocumentVersionID),
        CONSTRAINT CK_SourceRevision_OneSource CHECK
            ((CASE WHEN PostRevisionID IS NULL THEN 0 ELSE 1 END)
             + (CASE WHEN CommentRevisionID IS NULL THEN 0 ELSE 1 END)
             + (CASE WHEN DocumentVersionID IS NULL THEN 0 ELSE 1 END) = 1),
        CONSTRAINT CK_SourceRevision_Status CHECK (ProcessingStatus IN ('PENDING','READY','FAILED')),
        CONSTRAINT CK_SourceRevision_Processed CHECK (ProcessingStatus <> 'READY' OR
            (ExtractedText IS NOT NULL AND TextHash IS NOT NULL AND ProcessedAt IS NOT NULL))
    );
END;
GO

/* Offsets are zero-based in the extracted text; PageNo is the source page when known. */
IF OBJECT_ID(N'knowledge.Chunk', N'U') IS NULL
BEGIN
    CREATE TABLE knowledge.Chunk
    (
        ChunkID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Chunk PRIMARY KEY,
        SourceRevisionID bigint NOT NULL,
        ChunkNo int NOT NULL,
        ChunkText nvarchar(max) NOT NULL,
        PageNo int NULL,
        StartOffset int NOT NULL,
        EndOffset int NOT NULL,
        ChunkHash binary(32) NOT NULL,
        ChunkStatus varchar(8) NOT NULL CONSTRAINT DF_Chunk_Status DEFAULT ('READY'),
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_Chunk_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_Chunk_SourceRevision FOREIGN KEY (SourceRevisionID) REFERENCES knowledge.SourceRevision(SourceRevisionID),
        CONSTRAINT CK_Chunk_Ordinal CHECK (ChunkNo > 0),
        CONSTRAINT CK_Chunk_Page CHECK (PageNo IS NULL OR PageNo > 0),
        CONSTRAINT CK_Chunk_Offsets CHECK (StartOffset >= 0 AND EndOffset > StartOffset),
        CONSTRAINT CK_Chunk_Text CHECK (DATALENGTH(ChunkText) > 0),
        CONSTRAINT CK_Chunk_Status CHECK (ChunkStatus IN ('READY','STALE'))
    ) AS NODE;
END;
GO
