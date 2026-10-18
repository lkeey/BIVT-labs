/* RAG execution trail; citations must point to a chunk that was retrieved. */
IF OBJECT_ID(N'assistant.RagSession', N'U') IS NULL
BEGIN
    CREATE TABLE assistant.RagSession
    (
        SessionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_RagSession PRIMARY KEY,
        UserID bigint NOT NULL,
        Scope varchar(16) NOT NULL CONSTRAINT DF_RagSession_Scope DEFAULT ('AllAccessible'),
        CommunityID bigint NULL,
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_RagSession_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_RagSession_User FOREIGN KEY (UserID) REFERENCES auth.UserAccount(UserID),
        CONSTRAINT FK_RagSession_Community FOREIGN KEY (CommunityID) REFERENCES social.Community(CommunityID),
        CONSTRAINT CK_RagSession_Scope CHECK (Scope IN ('AllAccessible','Community')),
        CONSTRAINT CK_RagSession_ScopeCommunity CHECK
            ((Scope = 'AllAccessible' AND CommunityID IS NULL) OR (Scope = 'Community' AND CommunityID IS NOT NULL))
    );
END;
GO

IF OBJECT_ID(N'assistant.RagTurn', N'U') IS NULL
BEGIN
    CREATE TABLE assistant.RagTurn
    (
        TurnID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_RagTurn PRIMARY KEY,
        SessionID bigint NOT NULL,
        TurnNo int NOT NULL,
        QuestionText nvarchar(2000) NOT NULL,
        AnswerText nvarchar(max) NULL,
        AnswerModel nvarchar(120) NULL,
        GenerationStatus varchar(12) NOT NULL CONSTRAINT DF_RagTurn_Status DEFAULT ('PENDING'),
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_RagTurn_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CompletedAt datetime2(3) NULL,
        CONSTRAINT FK_RagTurn_Session FOREIGN KEY (SessionID) REFERENCES assistant.RagSession(SessionID),
        CONSTRAINT UQ_RagTurn_Session_Number UNIQUE (SessionID,TurnNo),
        CONSTRAINT CK_RagTurn_Number CHECK (TurnNo > 0),
        CONSTRAINT CK_RagTurn_Status CHECK (GenerationStatus IN ('PENDING','COMPLETED','FAILED','NO_SOURCES'))
    );
END;
GO

IF OBJECT_ID(N'assistant.RetrievalRun', N'U') IS NULL
BEGIN
    CREATE TABLE assistant.RetrievalRun
    (
        RetrievalRunID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_RetrievalRun PRIMARY KEY,
        TurnID bigint NOT NULL,
        RetrievalMode varchar(16) NOT NULL CONSTRAINT DF_RetrievalRun_Mode DEFAULT ('HYBRID_GRAPH'),
        AccessPolicyVersion nvarchar(40) NOT NULL CONSTRAINT DF_RetrievalRun_Policy DEFAULT (N'1'),
        ModelVersion nvarchar(120) NOT NULL,
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_RetrievalRun_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_RetrievalRun_Turn FOREIGN KEY (TurnID) REFERENCES assistant.RagTurn(TurnID),
        CONSTRAINT CK_RetrievalRun_Mode CHECK (RetrievalMode IN ('HYBRID_GRAPH','VECTOR','FULLTEXT'))
    );
END;
GO

IF OBJECT_ID(N'assistant.RetrievedChunk', N'U') IS NULL
BEGIN
    CREATE TABLE assistant.RetrievedChunk
    (
        RetrievalRunID bigint NOT NULL,
        ChunkID bigint NOT NULL,
        [Rank] int NOT NULL,
        VectorScore decimal(9,6) NULL,
        TextScore decimal(9,6) NULL,
        GraphScore decimal(9,6) NULL,
        Snippet nvarchar(1000) NOT NULL,
        CONSTRAINT PK_RetrievedChunk PRIMARY KEY (RetrievalRunID,ChunkID),
        CONSTRAINT UQ_RetrievedChunk_Run_Rank UNIQUE (RetrievalRunID,[Rank]),
        CONSTRAINT FK_RetrievedChunk_Run FOREIGN KEY (RetrievalRunID) REFERENCES assistant.RetrievalRun(RetrievalRunID),
        CONSTRAINT FK_RetrievedChunk_Chunk FOREIGN KEY (ChunkID) REFERENCES knowledge.Chunk(ChunkID),
        CONSTRAINT CK_RetrievedChunk_Rank CHECK ([Rank] > 0)
    );
END;
GO

IF OBJECT_ID(N'assistant.AnswerCitation', N'U') IS NULL
BEGIN
    CREATE TABLE assistant.AnswerCitation
    (
        CitationID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_AnswerCitation PRIMARY KEY,
        RetrievalRunID bigint NOT NULL,
        ChunkID bigint NOT NULL,
        QuoteText nvarchar(1000) NOT NULL,
        PageNo int NULL,
        StartOffset int NOT NULL,
        EndOffset int NOT NULL,
        CONSTRAINT FK_AnswerCitation_Retrieved FOREIGN KEY (RetrievalRunID,ChunkID)
            REFERENCES assistant.RetrievedChunk(RetrievalRunID,ChunkID),
        CONSTRAINT CK_AnswerCitation_Page CHECK (PageNo IS NULL OR PageNo > 0),
        CONSTRAINT CK_AnswerCitation_Offsets CHECK (StartOffset >= 0 AND EndOffset > StartOffset)
    );
END;
GO

IF OBJECT_ID(N'assistant.TurnFeedback', N'U') IS NULL
BEGIN
    CREATE TABLE assistant.TurnFeedback
    (
        TurnID bigint NOT NULL CONSTRAINT PK_TurnFeedback PRIMARY KEY,
        UserID bigint NOT NULL,
        Rating smallint NOT NULL,
        Comment nvarchar(1000) NULL,
        SubmittedAt datetime2(3) NOT NULL CONSTRAINT DF_TurnFeedback_SubmittedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_TurnFeedback_Turn FOREIGN KEY (TurnID) REFERENCES assistant.RagTurn(TurnID),
        CONSTRAINT FK_TurnFeedback_User FOREIGN KEY (UserID) REFERENCES auth.UserAccount(UserID),
        CONSTRAINT CK_TurnFeedback_Rating CHECK (Rating BETWEEN 1 AND 5)
    );
END;
GO

IF OBJECT_ID(N'assistant.RecommendationBatch', N'U') IS NULL
BEGIN
    CREATE TABLE assistant.RecommendationBatch
    (
        BatchID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_RecommendationBatch PRIMARY KEY,
        UserID bigint NOT NULL,
        AlgorithmVersion nvarchar(40) NOT NULL,
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_RecommendationBatch_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_RecommendationBatch_User FOREIGN KEY (UserID) REFERENCES auth.UserAccount(UserID)
    );
END;
GO

IF OBJECT_ID(N'assistant.RecommendationItem', N'U') IS NULL
BEGIN
    CREATE TABLE assistant.RecommendationItem
    (
        BatchID bigint NOT NULL,
        ContentID bigint NOT NULL,
        [Rank] int NOT NULL,
        Score decimal(9,6) NOT NULL,
        ReasonCode varchar(24) NOT NULL,
        ReasonText nvarchar(500) NOT NULL,
        CONSTRAINT PK_RecommendationItem PRIMARY KEY (BatchID,ContentID),
        CONSTRAINT UQ_RecommendationItem_Batch_Rank UNIQUE (BatchID,[Rank]),
        CONSTRAINT FK_RecommendationItem_Batch FOREIGN KEY (BatchID) REFERENCES assistant.RecommendationBatch(BatchID),
        CONSTRAINT FK_RecommendationItem_Content FOREIGN KEY (ContentID) REFERENCES social.ContentItem(ContentID),
        CONSTRAINT CK_RecommendationItem_Rank CHECK ([Rank] > 0),
        CONSTRAINT CK_RecommendationItem_Score CHECK (Score BETWEEN 0 AND 1),
        CONSTRAINT CK_RecommendationItem_Reason CHECK (ReasonCode IN
            ('RELATED_TOPIC','FOLLOWED_AUTHOR','MEMBER_COMMUNITY','SIMILAR_INTEREST','POPULAR','FRESH'))
    );
END;
GO

/* A set-based trigger in script 08 enqueues source changes. Workers claim rows via a procedure. */
IF OBJECT_ID(N'ops.IndexOutbox', N'U') IS NULL
BEGIN
    CREATE TABLE ops.IndexOutbox
    (
        EventID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_IndexOutbox PRIMARY KEY,
        SourceRevisionID bigint NOT NULL,
        ModelID int NULL,
        Operation varchar(8) NOT NULL,
        EventStatus varchar(8) NOT NULL CONSTRAINT DF_IndexOutbox_Status DEFAULT ('PENDING'),
        AttemptCount int NOT NULL CONSTRAINT DF_IndexOutbox_Attempts DEFAULT (0),
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_IndexOutbox_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ClaimedAt datetime2(3) NULL,
        ClaimToken uniqueidentifier NULL,
        LeaseUntil datetime2(3) NULL,
        ProcessedAt datetime2(3) NULL,
        LastError nvarchar(2000) NULL,
        CONSTRAINT FK_IndexOutbox_Source FOREIGN KEY (SourceRevisionID) REFERENCES knowledge.SourceRevision(SourceRevisionID),
        CONSTRAINT FK_IndexOutbox_Model FOREIGN KEY (ModelID) REFERENCES knowledge.EmbeddingModel(ModelID),
        CONSTRAINT CK_IndexOutbox_Operation CHECK (Operation IN ('UPSERT','DELETE')),
        CONSTRAINT CK_IndexOutbox_Status CHECK (EventStatus IN ('PENDING','CLAIMED','DONE','FAILED')),
        CONSTRAINT CK_IndexOutbox_Attempts CHECK (AttemptCount >= 0),
        CONSTRAINT CK_IndexOutbox_Lease CHECK (LeaseUntil IS NULL OR ClaimedAt IS NOT NULL),
        CONSTRAINT CK_IndexOutbox_ClaimToken CHECK
            ((EventStatus = 'CLAIMED' AND ClaimToken IS NOT NULL)
             OR (EventStatus <> 'CLAIMED' AND ClaimToken IS NULL))
    );
END;
GO

IF OBJECT_ID(N'ops.AuditEvent', N'U') IS NULL
BEGIN
    CREATE TABLE ops.AuditEvent
    (
        AuditEventID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_AuditEvent PRIMARY KEY,
        ActorUserID bigint NULL,
        EventType varchar(40) NOT NULL,
        EntityType varchar(40) NOT NULL,
        EntityID bigint NOT NULL,
        CorrelationID uniqueidentifier NULL,
        Details nvarchar(max) NULL,
        OccurredAt datetime2(3) NOT NULL CONSTRAINT DF_AuditEvent_OccurredAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_AuditEvent_Actor FOREIGN KEY (ActorUserID) REFERENCES auth.UserAccount(UserID),
        CONSTRAINT CK_AuditEvent_Details CHECK (Details IS NULL OR ISJSON(Details) = 1)
    );
END;
GO
