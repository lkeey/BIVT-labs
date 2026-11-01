# Памятка по базе SocialNetworkDB

**Что хранит база:** пользователей и сообщества, их посты, комментарии и документы, данные для поиска, историю ответов и рекомендательную ленту. Это **одна база SQL Server 2025** с пятью схемами и 33 таблицами.

Ниже перечислены **главные поля**. Служебные даты, хеши и ограничения местами опущены, чтобы памятка оставалась короткой. Полный список столбцов — в [T-SQL-скриптах](../database/README.md).

**Типы:** Str — текст, Int64/Int32 — число, Bool — да/нет, DateTime — дата и время, Bytes — файл или байты, Decimal — дробное число, UUID — уникальный идентификатор, Vector[384] — вектор из 384 чисел, NodeRef — ссылка SQL Graph. Знак ? означает, что поле может быть пустым. PK — первичный ключ, FK — ссылка на другую таблицу.

Стрелка **→** ниже означает «связан с». Для обычных таблиц связь обычно хранится в FK; для графовых таблиц — в системных полях $from_id и $to_id. Это просто карта связей, без синтаксиса JOIN.

## 1. Пользователи и сообщества

### auth.UserAccount
- UserID: Int64 (PK)
- Login: Str
- EmailNormalized: Str
- AccountStatus: Str
- PasswordHash: Bytes?

### auth.UserProfile
- UserID: Int64 (PK, FK)
- DisplayName: Str
- Bio: Str?
- ProfileVisibility: Str

### auth.ExternalIdentity
- FirebaseUID: Str (PK)
- UserID: Int64 (FK)

### social.Community
- CommunityID: Int64 (PK)
- OwnerUserID: Int64 (FK)
- Slug: Str
- CommunityName: Str
- Visibility: Str
- Status: Str

### social.Follows
- $from_id: NodeRef
- $to_id: NodeRef

### social.MemberOf
- MembershipID: Int64 (PK)
- $from_id: NodeRef
- $to_id: NodeRef
- Role: Str
- MemberStatus: Str
- EndedAt: DateTime?

**Связи:**

- UserAccount → UserProfile
- UserAccount → ExternalIdentity
- UserAccount → Community (владелец)
- UserAccount → Follows → UserAccount (подписка)
- UserAccount → MemberOf → Community (членство)

## 2. Публикации

### social.ContentItem
- ContentID: Int64 (PK)
- Kind: Str (POST / COMMENT / DOCUMENT)
- ContentStatus: Str
- AllowRag: Bool
- PublishedAt: DateTime?

### social.Authored
- $from_id: NodeRef
- $to_id: NodeRef

### social.PublishedIn
- $from_id: NodeRef
- $to_id: NodeRef

### social.CommentOn
- $from_id: NodeRef
- $to_id: NodeRef

### social.ReactTo
- $from_id: NodeRef
- $to_id: NodeRef
- ReactionType: Str

### social.PostRevision
- RevisionID: Int64 (PK)
- ContentID: Int64 (FK)
- RevisionNo: Int32
- Body: Str
- EditedByUserID: Int64 (FK)
- IsCurrent: Bool

### social.CommentRevision
- RevisionID: Int64 (PK)
- ContentID: Int64 (FK)
- RevisionNo: Int32
- Body: Str
- CommentStatus: Str
- IsCurrent: Bool

### social.DocumentDetail
- ContentID: Int64 (PK, FK)
- Title: Str
- Description: Str?
- DocumentStatus: Str

### knowledge.DocumentVersion
- DocumentVersionID: Int64 (PK)
- ContentID: Int64 (FK)
- VersionNo: Int32
- MimeType: Str
- PlainText: Str?
- FileBytes: Bytes?
- IsCurrent: Bool
- OCRStatus: Str

**Связи:**

- UserAccount → Authored → ContentItem (автор)
- ContentItem (POST / DOCUMENT) → PublishedIn → Community
- ContentItem (COMMENT) → CommentOn → ContentItem (POST)
- UserAccount → ReactTo → ContentItem (POST / COMMENT)
- ContentItem (POST) → PostRevision
- ContentItem (COMMENT) → CommentRevision
- ContentItem (DOCUMENT) → DocumentDetail → DocumentVersion

У ContentItem нет отдельных полей AuthorID и CommunityID: автора и сообщество хранят рёбра Authored и PublishedIn. Комментарий получает сообщество через пост, к которому он относится. В DocumentVersion заполнено **либо PlainText, либо FileBytes**.

## 3. Поиск и граф знаний

### knowledge.SourceRevision
- SourceRevisionID: Int64 (PK)
- ContentID: Int64 (FK)
- PostRevisionID: Int64?
- CommentRevisionID: Int64?
- DocumentVersionID: Int64?
- ExtractedText: Str?
- ProcessingStatus: Str
- IsCurrent: Bool

### knowledge.Chunk
- ChunkID: Int64 (PK)
- SourceRevisionID: Int64 (FK)
- ChunkNo: Int32
- ChunkText: Str
- PageNo: Int32?
- StartOffset: Int32
- EndOffset: Int32

### knowledge.EmbeddingModel
- ModelID: Int32 (PK)
- ModelName: Str
- ModelVersion: Str
- Dimensions: Int32
- IsActive: Bool

### knowledge.ChunkEmbedding
- ChunkID: Int64 (PK, FK)
- ModelID: Int32 (PK, FK)
- Embedding: Vector[384]

### knowledge.KnowledgeEntity
- EntityID: Int64 (PK)
- EntityType: Str
- EntityName: Str
- ExtractorVersion: Str

### knowledge.ChunkOf
- $from_id: NodeRef
- $to_id: NodeRef

### knowledge.Mentions
- MentionID: Int64 (PK)
- $from_id: NodeRef
- $to_id: NodeRef
- EvidenceChunkID: Int64 (FK)
- EvidenceText: Str
- Confidence: Decimal

### knowledge.EntityRelation
- RelationID: Int64 (PK)
- $from_id: NodeRef
- $to_id: NodeRef
- PredicateCode: Str
- EvidenceChunkID: Int64 (FK)
- EvidenceText: Str
- Confidence: Decimal

**Связи:**

- PostRevision **или** CommentRevision **или** DocumentVersion → SourceRevision → Chunk
- Chunk → ChunkEmbedding ← EmbeddingModel
- Chunk → ChunkOf → ContentItem (исходный материал)
- Chunk → Mentions → KnowledgeEntity (упоминание)
- KnowledgeEntity → EntityRelation → KnowledgeEntity (связь понятий)
- Chunk → EntityRelation (текстовое свидетельство через EvidenceChunkID)

У SourceRevision заполнен **ровно один** из трёх ID редакции. Chunk — небольшой фрагмент текста; ChunkEmbedding — его числовой вектор. KnowledgeEntity и EntityRelation — сущности и связи, извлечённые из текста. Их можно использовать только вместе с доступным исходным фрагментом.

## 4. Вопросы и цитаты RAG

### assistant.RagSession
- SessionID: Int64 (PK)
- UserID: Int64 (FK)
- CommunityID: Int64? (FK)
- Scope: Str

### assistant.RagTurn
- TurnID: Int64 (PK)
- SessionID: Int64 (FK)
- TurnNo: Int32
- QuestionText: Str
- AnswerText: Str?
- GenerationStatus: Str

### assistant.RetrievalRun
- RetrievalRunID: Int64 (PK)
- TurnID: Int64 (FK)
- RetrievalMode: Str
- ModelVersion: Str

### assistant.RetrievedChunk
- RetrievalRunID: Int64 (PK, FK)
- ChunkID: Int64 (PK, FK)
- Rank: Int32
- Snippet: Str
- VectorScore: Decimal?
- TextScore: Decimal?
- GraphScore: Decimal?

### assistant.AnswerCitation
- CitationID: Int64 (PK)
- RetrievalRunID: Int64 (FK)
- ChunkID: Int64 (FK)
- QuoteText: Str
- PageNo: Int32?
- StartOffset: Int32
- EndOffset: Int32

### assistant.TurnFeedback
- TurnID: Int64 (PK, FK)
- UserID: Int64 (FK)
- Rating: Int32
- Comment: Str?

**Связи:**

- UserAccount → RagSession ← Community? (если поиск ограничен сообществом)
- RagSession → RagTurn → RetrievalRun → RetrievedChunk ← Chunk
- RetrievedChunk → AnswerCitation
- RagTurn → TurnFeedback ← UserAccount

RetrievedChunk записывает, какие фрагменты реально нашли. AnswerCitation может ссылаться только на такой фрагмент; SQL дополнительно проверяет, что текст цитаты есть в нём. При показе сохранённого ответа доступ к источнику проверяется снова.

## 5. Лента и служебные данные

### assistant.RecommendationBatch
- BatchID: Int64 (PK)
- UserID: Int64 (FK)
- AlgorithmVersion: Str

### assistant.RecommendationItem
- BatchID: Int64 (PK, FK)
- ContentID: Int64 (PK, FK)
- Rank: Int32
- Score: Decimal
- ReasonCode: Str
- ReasonText: Str

### ops.IndexOutbox
- EventID: Int64 (PK)
- SourceRevisionID: Int64 (FK)
- ModelID: Int32? (FK)
- Operation: Str
- EventStatus: Str
- AttemptCount: Int32
- LeaseUntil: DateTime?

### ops.AuditEvent
- AuditEventID: Int64 (PK)
- ActorUserID: Int64? (FK)
- EventType: Str
- EntityType: Str
- EntityID: Int64
- CorrelationID: UUID?

**Связи:**

- UserAccount → RecommendationBatch → RecommendationItem → ContentItem
- SourceRevision → IndexOutbox ← EmbeddingModel?
- UserAccount? → AuditEvent

RecommendationItem хранит материал, его место в ленте, оценку и объяснение рекомендации. IndexOutbox — очередь задач для обработки текста и обновления индекса. AuditEvent — журнал действий; пара EntityType + EntityID указывает на объект разных типов, поэтому общего FK на одну таблицу здесь нет.

## Вся идея в шести строках

1. Пользователь состоит в сообществе и публикует материал.
2. Материал имеет версии: пост, комментарий или документ.
3. Текущая версия превращается в текстовые фрагменты, векторы и связи графа.
4. Поиск выбирает только доступные пользователю фрагменты.
5. Ответ хранит цитаты со ссылкой на реально найденные фрагменты.
6. Лента хранит рекомендованные материалы, оценки и причины.

Это краткая памятка. Точные SQL-типы, все служебные поля и ограничения смотрите в [DDL](../database/README.md).
