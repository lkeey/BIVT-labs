# Памятка по таблицам SocialNetworkDB

Одна база SQL Server 2025: 33 таблицы в схемах `auth`, `social`, `knowledge`, `assistant` и `ops`.

**Как читать:** каждый прямоугольник — таблица, внутри видны её основные поля и типы. Стрелка показывает связь. `PK` — ключ таблицы, `FK` — ссылка на другую таблицу, `?` — поле может быть пустым. `NodeRef` — системная ссылка ребра SQL Graph. Повторяющиеся прямоугольники на разных рисунках обозначают одну и ту же таблицу. Точные SQL-типы и остальные служебные поля — в [T-SQL DDL](../database/README.md).

## 1. Пользователи и сообщества

Профиль и вход принадлежат пользователю. Подписка ведёт к другому пользователю; членство — к сообществу.

### Аккаунт, профиль и сообщество

~~~mermaid
flowchart TB
    U["auth.UserAccount<br/>UserID: Int64 (PK)<br/>Login: Str<br/>EmailNormalized: Str<br/>AccountStatus: Str<br/>PasswordHash: Bytes?"]
    P["auth.UserProfile<br/>UserID: Int64 (PK, FK)<br/>DisplayName: Str<br/>Bio: Str?<br/>ProfileVisibility: Str"]
    X["auth.ExternalIdentity<br/>FirebaseUID: Str (PK)<br/>UserID: Int64 (FK)"]
    C["social.Community<br/>CommunityID: Int64 (PK)<br/>OwnerUserID: Int64 (FK)<br/>Slug: Str<br/>CommunityName: Str<br/>Visibility: Str<br/>Status: Str"]
    U --> P
    U --> X
    U --> C
~~~

### Подписка и членство

~~~mermaid
flowchart TB
    U["auth.UserAccount<br/>UserID: Int64 (PK)<br/>Login: Str<br/>EmailNormalized: Str<br/>AccountStatus: Str<br/>PasswordHash: Bytes?"]
    F["social.Follows<br/>$from_id: NodeRef<br/>$to_id: NodeRef"]
    U2["auth.UserAccount (другой пользователь)<br/>UserID: Int64 (PK)<br/>Login: Str<br/>EmailNormalized: Str<br/>AccountStatus: Str<br/>PasswordHash: Bytes?"]
    M["social.MemberOf<br/>MembershipID: Int64 (PK)<br/>$from_id: NodeRef<br/>$to_id: NodeRef<br/>Role: Str<br/>MemberStatus: Str<br/>EndedAt: DateTime?"]
    C["social.Community<br/>CommunityID: Int64 (PK)<br/>OwnerUserID: Int64 (FK)<br/>Slug: Str<br/>CommunityName: Str<br/>Visibility: Str<br/>Status: Str"]
    U --> F --> U2
    U --> M --> C
~~~

## 2. Публикации

ContentItem — общая запись поста, комментария или документа. Текст и файл лежат в таблицах версий. У документа заполнено либо `PlainText`, либо `FileBytes`.

### Автор и сообщество

~~~mermaid
flowchart TB
    U["auth.UserAccount<br/>UserID: Int64 (PK)<br/>Login: Str<br/>EmailNormalized: Str<br/>AccountStatus: Str<br/>PasswordHash: Bytes?"]
    A["social.Authored<br/>$from_id: NodeRef<br/>$to_id: NodeRef"]
    I["social.ContentItem<br/>ContentID: Int64 (PK)<br/>Kind: Str (POST / COMMENT / DOCUMENT)<br/>ContentStatus: Str<br/>AllowRag: Bool<br/>PublishedAt: DateTime?"]
    P["social.PublishedIn<br/>$from_id: NodeRef<br/>$to_id: NodeRef"]
    C["social.Community<br/>CommunityID: Int64 (PK)<br/>OwnerUserID: Int64 (FK)<br/>Slug: Str<br/>CommunityName: Str<br/>Visibility: Str<br/>Status: Str"]
    U --> A --> I --> P --> C
~~~

### Комментарий и реакция

~~~mermaid
flowchart TB
    CM["social.ContentItem (COMMENT)<br/>ContentID: Int64 (PK)<br/>Kind: Str (POST / COMMENT / DOCUMENT)<br/>ContentStatus: Str<br/>AllowRag: Bool<br/>PublishedAt: DateTime?"]
    CO["social.CommentOn<br/>$from_id: NodeRef<br/>$to_id: NodeRef"]
    P["social.ContentItem (POST)<br/>ContentID: Int64 (PK)<br/>Kind: Str (POST / COMMENT / DOCUMENT)<br/>ContentStatus: Str<br/>AllowRag: Bool<br/>PublishedAt: DateTime?"]
    U["auth.UserAccount<br/>UserID: Int64 (PK)<br/>Login: Str<br/>EmailNormalized: Str<br/>AccountStatus: Str<br/>PasswordHash: Bytes?"]
    R["social.ReactTo<br/>$from_id: NodeRef<br/>$to_id: NodeRef<br/>ReactionType: Str"]
    CM --> CO --> P
    U --> R --> P
~~~

### Версии поста и комментария

~~~mermaid
flowchart TB
    P["social.ContentItem (POST)<br/>ContentID: Int64 (PK)<br/>Kind: Str (POST / COMMENT / DOCUMENT)<br/>ContentStatus: Str<br/>AllowRag: Bool<br/>PublishedAt: DateTime?"]
    PR["social.PostRevision<br/>RevisionID: Int64 (PK)<br/>ContentID: Int64 (FK)<br/>RevisionNo: Int32<br/>Body: Str<br/>EditedByUserID: Int64 (FK)<br/>IsCurrent: Bool"]
    C["social.ContentItem (COMMENT)<br/>ContentID: Int64 (PK)<br/>Kind: Str (POST / COMMENT / DOCUMENT)<br/>ContentStatus: Str<br/>AllowRag: Bool<br/>PublishedAt: DateTime?"]
    CR["social.CommentRevision<br/>RevisionID: Int64 (PK)<br/>ContentID: Int64 (FK)<br/>RevisionNo: Int32<br/>Body: Str<br/>CommentStatus: Str<br/>IsCurrent: Bool"]
    P --> PR
    C --> CR
~~~

### Версии документа

~~~mermaid
flowchart TB
    I["social.ContentItem (DOCUMENT)<br/>ContentID: Int64 (PK)<br/>Kind: Str (POST / COMMENT / DOCUMENT)<br/>ContentStatus: Str<br/>AllowRag: Bool<br/>PublishedAt: DateTime?"]
    D["social.DocumentDetail<br/>ContentID: Int64 (PK, FK)<br/>Title: Str<br/>Description: Str?<br/>DocumentStatus: Str"]
    V["knowledge.DocumentVersion<br/>DocumentVersionID: Int64 (PK)<br/>ContentID: Int64 (FK)<br/>VersionNo: Int32<br/>MimeType: Str<br/>PlainText: Str?<br/>FileBytes: Bytes?<br/>IsCurrent: Bool<br/>OCRStatus: Str"]
    I --> D --> V
~~~

## 3. Поиск и граф знаний

`SourceRevision` указывает ровно на одну версию поста, комментария или документа. Она превращается во фрагменты; для каждого можно хранить вектор, упоминания и связи с источником.

### От версии к фрагменту

~~~mermaid
flowchart TB
    P["social.PostRevision<br/>RevisionID: Int64 (PK)<br/>ContentID: Int64 (FK)<br/>RevisionNo: Int32<br/>Body: Str<br/>EditedByUserID: Int64 (FK)<br/>IsCurrent: Bool"]
    C["social.CommentRevision<br/>RevisionID: Int64 (PK)<br/>ContentID: Int64 (FK)<br/>RevisionNo: Int32<br/>Body: Str<br/>CommentStatus: Str<br/>IsCurrent: Bool"]
    D["knowledge.DocumentVersion<br/>DocumentVersionID: Int64 (PK)<br/>ContentID: Int64 (FK)<br/>VersionNo: Int32<br/>MimeType: Str<br/>PlainText: Str?<br/>FileBytes: Bytes?<br/>IsCurrent: Bool<br/>OCRStatus: Str"]
    S["knowledge.SourceRevision<br/>SourceRevisionID: Int64 (PK)<br/>ContentID: Int64 (FK)<br/>PostRevisionID: Int64?<br/>CommentRevisionID: Int64?<br/>DocumentVersionID: Int64?<br/>ExtractedText: Str?<br/>ProcessingStatus: Str<br/>IsCurrent: Bool"]
    K["knowledge.Chunk<br/>ChunkID: Int64 (PK)<br/>SourceRevisionID: Int64 (FK)<br/>ChunkNo: Int32<br/>ChunkText: Str<br/>PageNo: Int32?<br/>StartOffset: Int32<br/>EndOffset: Int32"]
    P --> S
    C --> S
    D --> S
    S --> K
~~~

### Векторы

~~~mermaid
flowchart TB
    K["knowledge.Chunk<br/>ChunkID: Int64 (PK)<br/>SourceRevisionID: Int64 (FK)<br/>ChunkNo: Int32<br/>ChunkText: Str<br/>PageNo: Int32?<br/>StartOffset: Int32<br/>EndOffset: Int32"]
    E["knowledge.ChunkEmbedding<br/>ChunkID: Int64 (PK, FK)<br/>ModelID: Int32 (PK, FK)<br/>Embedding: Vector[384]"]
    M["knowledge.EmbeddingModel<br/>ModelID: Int32 (PK)<br/>ModelName: Str<br/>ModelVersion: Str<br/>Dimensions: Int32<br/>IsActive: Bool"]
    K --> E
    M --> E
~~~

### Упоминания в исходном материале

~~~mermaid
flowchart TB
    K["knowledge.Chunk<br/>ChunkID: Int64 (PK)<br/>SourceRevisionID: Int64 (FK)<br/>ChunkNo: Int32<br/>ChunkText: Str<br/>PageNo: Int32?<br/>StartOffset: Int32<br/>EndOffset: Int32"]
    O["knowledge.ChunkOf<br/>$from_id: NodeRef<br/>$to_id: NodeRef"]
    I["social.ContentItem<br/>ContentID: Int64 (PK)<br/>Kind: Str (POST / COMMENT / DOCUMENT)<br/>ContentStatus: Str<br/>AllowRag: Bool<br/>PublishedAt: DateTime?"]
    M["knowledge.Mentions<br/>MentionID: Int64 (PK)<br/>$from_id: NodeRef<br/>$to_id: NodeRef<br/>EvidenceChunkID: Int64 (FK)<br/>EvidenceText: Str<br/>Confidence: Decimal"]
    E["knowledge.KnowledgeEntity<br/>EntityID: Int64 (PK)<br/>EntityType: Str<br/>EntityName: Str<br/>ExtractorVersion: Str"]
    K --> O --> I
    K --> M --> E
~~~

### Связи сущностей

~~~mermaid
flowchart TB
    E["knowledge.KnowledgeEntity<br/>EntityID: Int64 (PK)<br/>EntityType: Str<br/>EntityName: Str<br/>ExtractorVersion: Str"]
    R["knowledge.EntityRelation<br/>RelationID: Int64 (PK)<br/>$from_id: NodeRef<br/>$to_id: NodeRef<br/>PredicateCode: Str<br/>EvidenceChunkID: Int64 (FK)<br/>EvidenceText: Str<br/>Confidence: Decimal"]
    E2["knowledge.KnowledgeEntity (другая сущность)<br/>EntityID: Int64 (PK)<br/>EntityType: Str<br/>EntityName: Str<br/>ExtractorVersion: Str"]
    K["knowledge.Chunk<br/>ChunkID: Int64 (PK)<br/>SourceRevisionID: Int64 (FK)<br/>ChunkNo: Int32<br/>ChunkText: Str<br/>PageNo: Int32?<br/>StartOffset: Int32<br/>EndOffset: Int32"]
    E --> R --> E2
    K --> R
~~~

## 4. Вопросы и цитаты RAG

Сохраняются вопрос, найденные фрагменты и цитата. Цитата может вести только к фрагменту из сохранённой выдачи.

### Диалог и оценка ответа

~~~mermaid
flowchart TB
    U["auth.UserAccount<br/>UserID: Int64 (PK)<br/>Login: Str<br/>EmailNormalized: Str<br/>AccountStatus: Str<br/>PasswordHash: Bytes?"]
    C["social.Community<br/>CommunityID: Int64 (PK)<br/>OwnerUserID: Int64 (FK)<br/>Slug: Str<br/>CommunityName: Str<br/>Visibility: Str<br/>Status: Str"]
    S["assistant.RagSession<br/>SessionID: Int64 (PK)<br/>UserID: Int64 (FK)<br/>CommunityID: Int64? (FK)<br/>Scope: Str"]
    T["assistant.RagTurn<br/>TurnID: Int64 (PK)<br/>SessionID: Int64 (FK)<br/>TurnNo: Int32<br/>QuestionText: Str<br/>AnswerText: Str?<br/>GenerationStatus: Str"]
    F["assistant.TurnFeedback<br/>TurnID: Int64 (PK, FK)<br/>UserID: Int64 (FK)<br/>Rating: Int32<br/>Comment: Str?"]
    U --> S
    C --> S
    S --> T --> F
    U --> F
~~~

### Поиск и цитирование

~~~mermaid
flowchart TB
    T["assistant.RagTurn<br/>TurnID: Int64 (PK)<br/>SessionID: Int64 (FK)<br/>TurnNo: Int32<br/>QuestionText: Str<br/>AnswerText: Str?<br/>GenerationStatus: Str"]
    R["assistant.RetrievalRun<br/>RetrievalRunID: Int64 (PK)<br/>TurnID: Int64 (FK)<br/>RetrievalMode: Str<br/>ModelVersion: Str"]
    K["knowledge.Chunk<br/>ChunkID: Int64 (PK)<br/>SourceRevisionID: Int64 (FK)<br/>ChunkNo: Int32<br/>ChunkText: Str<br/>PageNo: Int32?<br/>StartOffset: Int32<br/>EndOffset: Int32"]
    F["assistant.RetrievedChunk<br/>RetrievalRunID: Int64 (PK, FK)<br/>ChunkID: Int64 (PK, FK)<br/>Rank: Int32<br/>Snippet: Str<br/>VectorScore: Decimal?<br/>TextScore: Decimal?<br/>GraphScore: Decimal?"]
    C["assistant.AnswerCitation<br/>CitationID: Int64 (PK)<br/>RetrievalRunID: Int64 (FK)<br/>ChunkID: Int64 (FK)<br/>QuoteText: Str<br/>PageNo: Int32?<br/>StartOffset: Int32<br/>EndOffset: Int32"]
    T --> R --> F --> C
    K --> F
~~~

## 5. Лента и служебные записи

Лента хранит рассчитанный порядок материалов; очередь запускает обработку новых версий, журнал фиксирует действия.

### Рекомендательная лента

~~~mermaid
flowchart TB
    U["auth.UserAccount<br/>UserID: Int64 (PK)<br/>Login: Str<br/>EmailNormalized: Str<br/>AccountStatus: Str<br/>PasswordHash: Bytes?"]
    B["assistant.RecommendationBatch<br/>BatchID: Int64 (PK)<br/>UserID: Int64 (FK)<br/>AlgorithmVersion: Str"]
    I["assistant.RecommendationItem<br/>BatchID: Int64 (PK, FK)<br/>ContentID: Int64 (PK, FK)<br/>Rank: Int32<br/>Score: Decimal<br/>ReasonCode: Str<br/>ReasonText: Str"]
    C["social.ContentItem<br/>ContentID: Int64 (PK)<br/>Kind: Str (POST / COMMENT / DOCUMENT)<br/>ContentStatus: Str<br/>AllowRag: Bool<br/>PublishedAt: DateTime?"]
    U --> B --> I --> C
~~~

### Индексация

~~~mermaid
flowchart TB
    S["knowledge.SourceRevision<br/>SourceRevisionID: Int64 (PK)<br/>ContentID: Int64 (FK)<br/>PostRevisionID: Int64?<br/>CommentRevisionID: Int64?<br/>DocumentVersionID: Int64?<br/>ExtractedText: Str?<br/>ProcessingStatus: Str<br/>IsCurrent: Bool"]
    M["knowledge.EmbeddingModel<br/>ModelID: Int32 (PK)<br/>ModelName: Str<br/>ModelVersion: Str<br/>Dimensions: Int32<br/>IsActive: Bool"]
    O["ops.IndexOutbox<br/>EventID: Int64 (PK)<br/>SourceRevisionID: Int64 (FK)<br/>ModelID: Int32? (FK)<br/>Operation: Str<br/>EventStatus: Str<br/>AttemptCount: Int32<br/>LeaseUntil: DateTime?"]
    S --> O
    M --> O
~~~

### Журнал действий

~~~mermaid
flowchart TB
    U["auth.UserAccount<br/>UserID: Int64 (PK)<br/>Login: Str<br/>EmailNormalized: Str<br/>AccountStatus: Str<br/>PasswordHash: Bytes?"]
    A["ops.AuditEvent<br/>AuditEventID: Int64 (PK)<br/>ActorUserID: Int64? (FK)<br/>EventType: Str<br/>EntityType: Str<br/>EntityID: Int64<br/>CorrelationID: UUID?"]
    U --> A
~~~

**Три главные цепочки:** пользователь → сообщество → материал; материал → версия → фрагмент → сущность; вопрос → найденный фрагмент → цитата.
