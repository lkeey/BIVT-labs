/* Filtered indexes require these session options when applied through sqlcmd. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* One current snapshot per material; old snapshots remain for audit only. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.PostRevision') AND name = N'UX_PostRevision_Current')
    CREATE UNIQUE INDEX UX_PostRevision_Current ON social.PostRevision(ContentID) WHERE IsCurrent = 1;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.CommentRevision') AND name = N'UX_CommentRevision_Current')
    CREATE UNIQUE INDEX UX_CommentRevision_Current ON social.CommentRevision(ContentID) WHERE IsCurrent = 1;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'knowledge.DocumentVersion') AND name = N'UX_DocumentVersion_Current')
    CREATE UNIQUE INDEX UX_DocumentVersion_Current ON knowledge.DocumentVersion(ContentID) WHERE IsCurrent = 1;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'knowledge.SourceRevision') AND name = N'UX_SourceRevision_Current')
    CREATE UNIQUE INDEX UX_SourceRevision_Current ON knowledge.SourceRevision(ContentID) WHERE IsCurrent = 1;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'knowledge.SourceRevision') AND name = N'UX_SourceRevision_Post')
    CREATE UNIQUE INDEX UX_SourceRevision_Post ON knowledge.SourceRevision(PostRevisionID) WHERE PostRevisionID IS NOT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'knowledge.SourceRevision') AND name = N'UX_SourceRevision_Comment')
    CREATE UNIQUE INDEX UX_SourceRevision_Comment ON knowledge.SourceRevision(CommentRevisionID) WHERE CommentRevisionID IS NOT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'knowledge.SourceRevision') AND name = N'UX_SourceRevision_Document')
    CREATE UNIQUE INDEX UX_SourceRevision_Document ON knowledge.SourceRevision(DocumentVersionID) WHERE DocumentVersionID IS NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.ContentItem') AND name = N'IX_ContentItem_Visible')
    CREATE INDEX IX_ContentItem_Visible ON social.ContentItem(ContentStatus,Kind,AllowRag,PublishedAt DESC) INCLUDE (UpdatedAt);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'knowledge.SourceRevision') AND name = N'IX_SourceRevision_Ready')
    CREATE INDEX IX_SourceRevision_Ready ON knowledge.SourceRevision(IsCurrent,ProcessingStatus,ContentID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'knowledge.Chunk') AND name = N'IX_Chunk_Source_Status')
    CREATE INDEX IX_Chunk_Source_Status ON knowledge.Chunk(SourceRevisionID,ChunkStatus,ChunkNo) INCLUDE (PageNo,StartOffset,EndOffset);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'knowledge.Chunk') AND name = N'UX_Chunk_Ready_Ordinal')
    CREATE UNIQUE INDEX UX_Chunk_Ready_Ordinal ON knowledge.Chunk(SourceRevisionID,ChunkNo) WHERE ChunkStatus = 'READY';
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'knowledge.ChunkEmbedding') AND name = N'IX_ChunkEmbedding_Model')
    CREATE INDEX IX_ChunkEmbedding_Model ON knowledge.ChunkEmbedding(ModelID,ChunkID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'knowledge.EmbeddingModel') AND name = N'UX_EmbeddingModel_OneActive')
    CREATE UNIQUE INDEX UX_EmbeddingModel_OneActive ON knowledge.EmbeddingModel(IsActive) WHERE IsActive = 1;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'knowledge.KnowledgeEntity') AND name = N'IX_KnowledgeEntity_Type_Name')
    CREATE INDEX IX_KnowledgeEntity_Type_Name ON knowledge.KnowledgeEntity(EntityType,EntityName);
GO

/* SQL Graph endpoint indexes support ACL and recommendation traversals. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.Follows') AND name = N'UX_Follows_Pair')
    CREATE UNIQUE INDEX UX_Follows_Pair ON social.Follows($from_id,$to_id);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.Follows') AND name = N'IX_Follows_To')
    CREATE INDEX IX_Follows_To ON social.Follows($to_id,$from_id);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.MemberOf') AND name = N'UX_MemberOf_Active')
    CREATE UNIQUE INDEX UX_MemberOf_Active ON social.MemberOf($from_id,$to_id) WHERE MemberStatus = 'ACTIVE' AND EndedAt IS NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.MemberOf') AND name = N'IX_MemberOf_Community')
    CREATE INDEX IX_MemberOf_Community ON social.MemberOf($to_id,$from_id,MemberStatus,EndedAt);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.Authored') AND name = N'UX_Authored_Content')
    CREATE UNIQUE INDEX UX_Authored_Content ON social.Authored($to_id);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.Authored') AND name = N'IX_Authored_User')
    CREATE INDEX IX_Authored_User ON social.Authored($from_id,$to_id);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.PublishedIn') AND name = N'UX_PublishedIn_Content')
    CREATE UNIQUE INDEX UX_PublishedIn_Content ON social.PublishedIn($from_id);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.PublishedIn') AND name = N'IX_PublishedIn_Community')
    CREATE INDEX IX_PublishedIn_Community ON social.PublishedIn($to_id,$from_id);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.CommentOn') AND name = N'UX_CommentOn_Comment')
    CREATE UNIQUE INDEX UX_CommentOn_Comment ON social.CommentOn($from_id);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.CommentOn') AND name = N'IX_CommentOn_Parent')
    CREATE INDEX IX_CommentOn_Parent ON social.CommentOn($to_id,$from_id);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.ReactTo') AND name = N'UX_ReactTo_User_Content')
    CREATE UNIQUE INDEX UX_ReactTo_User_Content ON social.ReactTo($from_id,$to_id);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'social.ReactTo') AND name = N'IX_ReactTo_Content_User')
    CREATE INDEX IX_ReactTo_Content_User ON social.ReactTo($to_id,$from_id);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'knowledge.ChunkOf') AND name = N'UX_ChunkOf_Chunk')
    CREATE UNIQUE INDEX UX_ChunkOf_Chunk ON knowledge.ChunkOf($from_id);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'knowledge.ChunkOf') AND name = N'IX_ChunkOf_Content')
    CREATE INDEX IX_ChunkOf_Content ON knowledge.ChunkOf($to_id,$from_id);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'knowledge.Mentions') AND name = N'IX_Mentions_Chunk')
    CREATE INDEX IX_Mentions_Chunk ON knowledge.Mentions(EvidenceChunkID,$to_id);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'knowledge.EntityRelation') AND name = N'IX_EntityRelation_Evidence')
    CREATE INDEX IX_EntityRelation_Evidence ON knowledge.EntityRelation(EvidenceChunkID,PredicateCode);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'assistant.RagTurn') AND name = N'IX_RagTurn_Session')
    CREATE INDEX IX_RagTurn_Session ON assistant.RagTurn(SessionID,CreatedAt DESC);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'assistant.RetrievedChunk') AND name = N'IX_RetrievedChunk_Chunk')
    CREATE INDEX IX_RetrievedChunk_Chunk ON assistant.RetrievedChunk(ChunkID,RetrievalRunID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'assistant.RecommendationBatch') AND name = N'IX_RecommendationBatch_User')
    CREATE INDEX IX_RecommendationBatch_User ON assistant.RecommendationBatch(UserID,CreatedAt DESC);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'ops.IndexOutbox') AND name = N'IX_IndexOutbox_Claim')
    CREATE INDEX IX_IndexOutbox_Claim ON ops.IndexOutbox(EventStatus,LeaseUntil,CreatedAt) INCLUDE (SourceRevisionID,Operation,AttemptCount);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'ops.AuditEvent') AND name = N'IX_AuditEvent_Entity')
    CREATE INDEX IX_AuditEvent_Entity ON ops.AuditEvent(EntityType,EntityID,OccurredAt DESC);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'ops.AuditEvent') AND name = N'IX_AuditEvent_Correlation')
    CREATE INDEX IX_AuditEvent_Correlation ON ops.AuditEvent(CorrelationID) WHERE CorrelationID IS NOT NULL;
GO

/* SQL Server Full-Text is part of the required hybrid retrieval pipeline. */
IF ISNULL(CONVERT(int,FULLTEXTSERVICEPROPERTY('IsFullTextInstalled')),0) <> 1
BEGIN
    ;THROW 51001, 'SQL Server Full-Text Search must be installed for the coursework database.', 1;
END;
GO
IF NOT EXISTS (SELECT 1 FROM sys.fulltext_catalogs WHERE name = N'CourseworkText')
    EXEC(N'CREATE FULLTEXT CATALOG CourseworkText AS DEFAULT;');
GO
IF NOT EXISTS (SELECT 1 FROM sys.fulltext_indexes WHERE object_id = OBJECT_ID(N'knowledge.Chunk'))
    EXEC(N'CREATE FULLTEXT INDEX ON knowledge.Chunk(ChunkText LANGUAGE 1049)
           KEY INDEX PK_Chunk ON CourseworkText WITH CHANGE_TRACKING AUTO;');
GO
