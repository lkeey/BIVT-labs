/* The chosen Russian-capable embedding model has exactly 384 float32 dimensions. */
IF OBJECT_ID(N'knowledge.EmbeddingModel', N'U') IS NULL
BEGIN
    CREATE TABLE knowledge.EmbeddingModel
    (
        ModelID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_EmbeddingModel PRIMARY KEY,
        Provider nvarchar(80) NOT NULL,
        ModelName nvarchar(200) NOT NULL,
        ModelVersion nvarchar(80) NOT NULL,
        Dimensions int NOT NULL CONSTRAINT DF_EmbeddingModel_Dimensions DEFAULT (384),
        IsActive bit NOT NULL CONSTRAINT DF_EmbeddingModel_Active DEFAULT (0),
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_EmbeddingModel_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_EmbeddingModel_Name_Version UNIQUE (ModelName,ModelVersion),
        CONSTRAINT CK_EmbeddingModel_Dimensions CHECK (Dimensions = 384)
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM knowledge.EmbeddingModel
    WHERE ModelName = N'intfloat/multilingual-e5-small'
      AND ModelVersion = N'fd1525a9fd15316a2d503bf26ab031a61d056e98'
)
BEGIN
    INSERT INTO knowledge.EmbeddingModel(Provider,ModelName,ModelVersion,Dimensions,IsActive)
    VALUES (N'Hugging Face',N'intfloat/multilingual-e5-small',
            N'fd1525a9fd15316a2d503bf26ab031a61d056e98',384,1);
END;
GO

IF OBJECT_ID(N'knowledge.ChunkEmbedding', N'U') IS NULL
BEGIN
    CREATE TABLE knowledge.ChunkEmbedding
    (
        ChunkID bigint NOT NULL,
        ModelID int NOT NULL,
        Embedding vector(384) NOT NULL,
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_ChunkEmbedding_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_ChunkEmbedding PRIMARY KEY (ChunkID,ModelID),
        CONSTRAINT FK_ChunkEmbedding_Chunk FOREIGN KEY (ChunkID) REFERENCES knowledge.Chunk(ChunkID),
        CONSTRAINT FK_ChunkEmbedding_Model FOREIGN KEY (ModelID) REFERENCES knowledge.EmbeddingModel(ModelID)
    );
END;
GO

/* No automatic entity merging or mandatory moderation. Every assertion retains evidence. */
IF OBJECT_ID(N'knowledge.KnowledgeEntity', N'U') IS NULL
BEGIN
    CREATE TABLE knowledge.KnowledgeEntity
    (
        EntityID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_KnowledgeEntity PRIMARY KEY,
        EntityType varchar(14) NOT NULL,
        EntityName nvarchar(500) NOT NULL,
        ExtractorVersion nvarchar(80) NOT NULL,
        CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_KnowledgeEntity_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT CK_KnowledgeEntity_Type CHECK (EntityType IN ('TOPIC','PERSON','ORGANIZATION','EVENT','PLACE'))
    ) AS NODE;
END;
GO

IF OBJECT_ID(N'knowledge.ChunkOf', N'U') IS NULL
BEGIN
    CREATE TABLE knowledge.ChunkOf
    (
        CONSTRAINT EC_ChunkOf_Chunk_Content CONNECTION (knowledge.Chunk TO social.ContentItem)
    ) AS EDGE;
END;
GO

IF OBJECT_ID(N'knowledge.Mentions', N'U') IS NULL
BEGIN
    CREATE TABLE knowledge.Mentions
    (
        MentionID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Mentions PRIMARY KEY,
        EvidenceChunkID bigint NOT NULL,
        StartOffset int NOT NULL,
        EndOffset int NOT NULL,
        EvidenceText nvarchar(1000) NOT NULL,
        Confidence decimal(4,3) NOT NULL,
        ExtractorVersion nvarchar(80) NOT NULL,
        ExtractedAt datetime2(3) NOT NULL CONSTRAINT DF_Mentions_ExtractedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_Mentions_Evidence FOREIGN KEY (EvidenceChunkID) REFERENCES knowledge.Chunk(ChunkID),
        CONSTRAINT CK_Mentions_Offsets CHECK (StartOffset >= 0 AND EndOffset > StartOffset),
        CONSTRAINT CK_Mentions_Confidence CHECK (Confidence BETWEEN 0 AND 1),
        CONSTRAINT EC_Mentions_Chunk_Entity CONNECTION (knowledge.Chunk TO knowledge.KnowledgeEntity)
    ) AS EDGE;
END;
GO

IF OBJECT_ID(N'knowledge.EntityRelation', N'U') IS NULL
BEGIN
    CREATE TABLE knowledge.EntityRelation
    (
        RelationID bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_EntityRelation PRIMARY KEY,
        PredicateCode varchar(20) NOT NULL,
        EvidenceChunkID bigint NOT NULL,
        StartOffset int NOT NULL,
        EndOffset int NOT NULL,
        EvidenceText nvarchar(1000) NOT NULL,
        Confidence decimal(4,3) NOT NULL,
        ExtractorVersion nvarchar(80) NOT NULL,
        ExtractedAt datetime2(3) NOT NULL CONSTRAINT DF_EntityRelation_ExtractedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_EntityRelation_Evidence FOREIGN KEY (EvidenceChunkID) REFERENCES knowledge.Chunk(ChunkID),
        CONSTRAINT CK_EntityRelation_Predicate CHECK (PredicateCode IN
            ('PARTICIPATES_IN','WORKS_AT','TAKES_PLACE_IN','RELATED_TO')),
        CONSTRAINT CK_EntityRelation_Offsets CHECK (StartOffset >= 0 AND EndOffset > StartOffset),
        CONSTRAINT CK_EntityRelation_Confidence CHECK (Confidence BETWEEN 0 AND 1),
        CONSTRAINT EC_EntityRelation_Entity_Entity CONNECTION (knowledge.KnowledgeEntity TO knowledge.KnowledgeEntity)
    ) AS EDGE;
END;
GO
