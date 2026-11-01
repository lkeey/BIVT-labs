# Памятка по таблицам SocialNetworkDB

Одна база SQL Server 2025: 33 таблицы в схемах `auth`, `social`, `knowledge`, `assistant` и `ops`.

**Как читать:** каждый прямоугольник — таблица, внутри видны её основные поля и типы. Стрелка показывает связь. `PK` — ключ таблицы, `FK` — ссылка на другую таблицу, `?` — поле может быть пустым. `NodeRef` — системная ссылка ребра SQL Graph. Повторяющиеся прямоугольники на разных рисунках обозначают одну и ту же таблицу. Точные SQL-типы и остальные служебные поля — в [T-SQL DDL](../database/README.md).

## 1. Пользователи и сообщества

Профиль и вход принадлежат пользователю. Подписка ведёт к другому пользователю; членство — к сообществу.

### Аккаунт, профиль и сообщество

~~~mermaid
classDiagram
    direction TB
    class U["auth.UserAccount"] {
        UserID : Int64 PK
        Login : Str
        EmailNormalized : Str
        AccountStatus : Str
        PasswordHash : Bytes?
    }
    class P["auth.UserProfile"] {
        UserID : Int64 PK FK
        DisplayName : Str
        Bio : Str?
        ProfileVisibility : Str
    }
    class X["auth.ExternalIdentity"] {
        FirebaseUID : Str PK
        UserID : Int64 FK
    }
    class C["social.Community"] {
        CommunityID : Int64 PK
        OwnerUserID : Int64 FK
        Slug : Str
        CommunityName : Str
        Visibility : Str
        Status : Str
    }
    U --> P
    U --> X
    U --> C
~~~

### Подписка и членство

~~~mermaid
classDiagram
    direction TB
    class U["auth.UserAccount"] {
        UserID : Int64 PK
        Login : Str
        EmailNormalized : Str
        AccountStatus : Str
        PasswordHash : Bytes?
    }
    class F["social.Follows"] {
        $from_id : NodeRef
        $to_id : NodeRef
    }
    class U2["auth.UserAccount (другой пользователь)"] {
        UserID : Int64 PK
        Login : Str
        EmailNormalized : Str
        AccountStatus : Str
        PasswordHash : Bytes?
    }
    class M["social.MemberOf"] {
        MembershipID : Int64 PK
        $from_id : NodeRef
        $to_id : NodeRef
        Role : Str
        MemberStatus : Str
        EndedAt : DateTime?
    }
    class C["social.Community"] {
        CommunityID : Int64 PK
        OwnerUserID : Int64 FK
        Slug : Str
        CommunityName : Str
        Visibility : Str
        Status : Str
    }
    U --> F
    F --> U2
    U --> M
    M --> C
~~~

## 2. Публикации

ContentItem — общая запись поста, комментария или документа. Текст и файл лежат в таблицах версий. У документа заполнено либо `PlainText`, либо `FileBytes`.

### Автор и сообщество

~~~mermaid
classDiagram
    direction TB
    class U["auth.UserAccount"] {
        UserID : Int64 PK
        Login : Str
        EmailNormalized : Str
        AccountStatus : Str
        PasswordHash : Bytes?
    }
    class A["social.Authored"] {
        $from_id : NodeRef
        $to_id : NodeRef
    }
    class I["social.ContentItem"] {
        ContentID : Int64 PK
        Kind : Str
        ContentStatus : Str
        AllowRag : Bool
        PublishedAt : DateTime?
    }
    class P["social.PublishedIn"] {
        $from_id : NodeRef
        $to_id : NodeRef
    }
    class C["social.Community"] {
        CommunityID : Int64 PK
        OwnerUserID : Int64 FK
        Slug : Str
        CommunityName : Str
        Visibility : Str
        Status : Str
    }
    U --> A
    A --> I
    I --> P
    P --> C
~~~

### Комментарий и реакция

~~~mermaid
classDiagram
    direction TB
    class CM["social.ContentItem (COMMENT)"] {
        ContentID : Int64 PK
        Kind : Str
        ContentStatus : Str
        AllowRag : Bool
        PublishedAt : DateTime?
    }
    class CO["social.CommentOn"] {
        $from_id : NodeRef
        $to_id : NodeRef
    }
    class P["social.ContentItem (POST)"] {
        ContentID : Int64 PK
        Kind : Str
        ContentStatus : Str
        AllowRag : Bool
        PublishedAt : DateTime?
    }
    class U["auth.UserAccount"] {
        UserID : Int64 PK
        Login : Str
        EmailNormalized : Str
        AccountStatus : Str
        PasswordHash : Bytes?
    }
    class R["social.ReactTo"] {
        $from_id : NodeRef
        $to_id : NodeRef
        ReactionType : Str
    }
    CM --> CO
    CO --> P
    U --> R
    R --> P
~~~

### Версии поста и комментария

~~~mermaid
classDiagram
    direction TB
    class P["social.ContentItem (POST)"] {
        ContentID : Int64 PK
        Kind : Str
        ContentStatus : Str
        AllowRag : Bool
        PublishedAt : DateTime?
    }
    class PR["social.PostRevision"] {
        RevisionID : Int64 PK
        ContentID : Int64 FK
        RevisionNo : Int32
        Body : Str
        EditedByUserID : Int64 FK
        IsCurrent : Bool
    }
    class C["social.ContentItem (COMMENT)"] {
        ContentID : Int64 PK
        Kind : Str
        ContentStatus : Str
        AllowRag : Bool
        PublishedAt : DateTime?
    }
    class CR["social.CommentRevision"] {
        RevisionID : Int64 PK
        ContentID : Int64 FK
        RevisionNo : Int32
        Body : Str
        CommentStatus : Str
        IsCurrent : Bool
    }
    P --> PR
    C --> CR
~~~

### Версии документа

~~~mermaid
classDiagram
    direction TB
    class I["social.ContentItem (DOCUMENT)"] {
        ContentID : Int64 PK
        Kind : Str
        ContentStatus : Str
        AllowRag : Bool
        PublishedAt : DateTime?
    }
    class D["social.DocumentDetail"] {
        ContentID : Int64 PK FK
        Title : Str
        Description : Str?
        DocumentStatus : Str
    }
    class V["knowledge.DocumentVersion"] {
        DocumentVersionID : Int64 PK
        ContentID : Int64 FK
        VersionNo : Int32
        MimeType : Str
        PlainText : Str?
        FileBytes : Bytes?
        IsCurrent : Bool
        OCRStatus : Str
    }
    I --> D
    D --> V
~~~

## 3. Поиск и граф знаний

`SourceRevision` указывает ровно на одну версию поста, комментария или документа. Она превращается во фрагменты; для каждого можно хранить вектор, упоминания и связи с источником.

### От версии к фрагменту

~~~mermaid
classDiagram
    direction TB
    class P["social.PostRevision"] {
        RevisionID : Int64 PK
        ContentID : Int64 FK
        RevisionNo : Int32
        Body : Str
        EditedByUserID : Int64 FK
        IsCurrent : Bool
    }
    class C["social.CommentRevision"] {
        RevisionID : Int64 PK
        ContentID : Int64 FK
        RevisionNo : Int32
        Body : Str
        CommentStatus : Str
        IsCurrent : Bool
    }
    class D["knowledge.DocumentVersion"] {
        DocumentVersionID : Int64 PK
        ContentID : Int64 FK
        VersionNo : Int32
        MimeType : Str
        PlainText : Str?
        FileBytes : Bytes?
        IsCurrent : Bool
        OCRStatus : Str
    }
    class S["knowledge.SourceRevision"] {
        SourceRevisionID : Int64 PK
        ContentID : Int64 FK
        PostRevisionID : Int64?
        CommentRevisionID : Int64?
        DocumentVersionID : Int64?
        ExtractedText : Str?
        ProcessingStatus : Str
        IsCurrent : Bool
    }
    class K["knowledge.Chunk"] {
        ChunkID : Int64 PK
        SourceRevisionID : Int64 FK
        ChunkNo : Int32
        ChunkText : Str
        PageNo : Int32?
        StartOffset : Int32
        EndOffset : Int32
    }
    P --> S
    C --> S
    D --> S
    S --> K
~~~

### Векторы

~~~mermaid
classDiagram
    direction TB
    class K["knowledge.Chunk"] {
        ChunkID : Int64 PK
        SourceRevisionID : Int64 FK
        ChunkNo : Int32
        ChunkText : Str
        PageNo : Int32?
        StartOffset : Int32
        EndOffset : Int32
    }
    class E["knowledge.ChunkEmbedding"] {
        ChunkID : Int64 PK FK
        ModelID : Int32 PK FK
        Embedding : Vector[384]
    }
    class M["knowledge.EmbeddingModel"] {
        ModelID : Int32 PK
        ModelName : Str
        ModelVersion : Str
        Dimensions : Int32
        IsActive : Bool
    }
    K --> E
    M --> E
~~~

### Упоминания в исходном материале

~~~mermaid
classDiagram
    direction TB
    class K["knowledge.Chunk"] {
        ChunkID : Int64 PK
        SourceRevisionID : Int64 FK
        ChunkNo : Int32
        ChunkText : Str
        PageNo : Int32?
        StartOffset : Int32
        EndOffset : Int32
    }
    class O["knowledge.ChunkOf"] {
        $from_id : NodeRef
        $to_id : NodeRef
    }
    class I["social.ContentItem"] {
        ContentID : Int64 PK
        Kind : Str
        ContentStatus : Str
        AllowRag : Bool
        PublishedAt : DateTime?
    }
    class M["knowledge.Mentions"] {
        MentionID : Int64 PK
        $from_id : NodeRef
        $to_id : NodeRef
        EvidenceChunkID : Int64 FK
        EvidenceText : Str
        Confidence : Decimal
    }
    class E["knowledge.KnowledgeEntity"] {
        EntityID : Int64 PK
        EntityType : Str
        EntityName : Str
        ExtractorVersion : Str
    }
    K --> O
    O --> I
    K --> M
    M --> E
~~~

### Связи сущностей

~~~mermaid
classDiagram
    direction TB
    class E["knowledge.KnowledgeEntity"] {
        EntityID : Int64 PK
        EntityType : Str
        EntityName : Str
        ExtractorVersion : Str
    }
    class R["knowledge.EntityRelation"] {
        RelationID : Int64 PK
        $from_id : NodeRef
        $to_id : NodeRef
        PredicateCode : Str
        EvidenceChunkID : Int64 FK
        EvidenceText : Str
        Confidence : Decimal
    }
    class E2["knowledge.KnowledgeEntity (другая сущность)"] {
        EntityID : Int64 PK
        EntityType : Str
        EntityName : Str
        ExtractorVersion : Str
    }
    class K["knowledge.Chunk"] {
        ChunkID : Int64 PK
        SourceRevisionID : Int64 FK
        ChunkNo : Int32
        ChunkText : Str
        PageNo : Int32?
        StartOffset : Int32
        EndOffset : Int32
    }
    E --> R
    R --> E2
    K --> R
~~~

## 4. Вопросы и цитаты RAG

Сохраняются вопрос, найденные фрагменты и цитата. Цитата может вести только к фрагменту из сохранённой выдачи.

### Диалог и оценка ответа

~~~mermaid
classDiagram
    direction TB
    class U["auth.UserAccount"] {
        UserID : Int64 PK
        Login : Str
        EmailNormalized : Str
        AccountStatus : Str
        PasswordHash : Bytes?
    }
    class C["social.Community"] {
        CommunityID : Int64 PK
        OwnerUserID : Int64 FK
        Slug : Str
        CommunityName : Str
        Visibility : Str
        Status : Str
    }
    class S["assistant.RagSession"] {
        SessionID : Int64 PK
        UserID : Int64 FK
        CommunityID : Int64? FK
        Scope : Str
    }
    class T["assistant.RagTurn"] {
        TurnID : Int64 PK
        SessionID : Int64 FK
        TurnNo : Int32
        QuestionText : Str
        AnswerText : Str?
        GenerationStatus : Str
    }
    class F["assistant.TurnFeedback"] {
        TurnID : Int64 PK FK
        UserID : Int64 FK
        Rating : Int32
        Comment : Str?
    }
    U --> S
    C --> S
    S --> T
    T --> F
    U --> F
~~~

### Поиск и цитирование

~~~mermaid
classDiagram
    direction TB
    class T["assistant.RagTurn"] {
        TurnID : Int64 PK
        SessionID : Int64 FK
        TurnNo : Int32
        QuestionText : Str
        AnswerText : Str?
        GenerationStatus : Str
    }
    class R["assistant.RetrievalRun"] {
        RetrievalRunID : Int64 PK
        TurnID : Int64 FK
        RetrievalMode : Str
        ModelVersion : Str
    }
    class K["knowledge.Chunk"] {
        ChunkID : Int64 PK
        SourceRevisionID : Int64 FK
        ChunkNo : Int32
        ChunkText : Str
        PageNo : Int32?
        StartOffset : Int32
        EndOffset : Int32
    }
    class F["assistant.RetrievedChunk"] {
        RetrievalRunID : Int64 PK FK
        ChunkID : Int64 PK FK
        Rank : Int32
        Snippet : Str
        VectorScore : Decimal?
        TextScore : Decimal?
        GraphScore : Decimal?
    }
    class C["assistant.AnswerCitation"] {
        CitationID : Int64 PK
        RetrievalRunID : Int64 FK
        ChunkID : Int64 FK
        QuoteText : Str
        PageNo : Int32?
        StartOffset : Int32
        EndOffset : Int32
    }
    T --> R
    R --> F
    F --> C
    K --> F
~~~

## 5. Лента и служебные записи

Лента хранит рассчитанный порядок материалов; очередь запускает обработку новых версий, журнал фиксирует действия.

### Рекомендательная лента

~~~mermaid
classDiagram
    direction TB
    class U["auth.UserAccount"] {
        UserID : Int64 PK
        Login : Str
        EmailNormalized : Str
        AccountStatus : Str
        PasswordHash : Bytes?
    }
    class B["assistant.RecommendationBatch"] {
        BatchID : Int64 PK
        UserID : Int64 FK
        AlgorithmVersion : Str
    }
    class I["assistant.RecommendationItem"] {
        BatchID : Int64 PK FK
        ContentID : Int64 PK FK
        Rank : Int32
        Score : Decimal
        ReasonCode : Str
        ReasonText : Str
    }
    class C["social.ContentItem"] {
        ContentID : Int64 PK
        Kind : Str
        ContentStatus : Str
        AllowRag : Bool
        PublishedAt : DateTime?
    }
    U --> B
    B --> I
    I --> C
~~~

### Индексация

~~~mermaid
classDiagram
    direction TB
    class S["knowledge.SourceRevision"] {
        SourceRevisionID : Int64 PK
        ContentID : Int64 FK
        PostRevisionID : Int64?
        CommentRevisionID : Int64?
        DocumentVersionID : Int64?
        ExtractedText : Str?
        ProcessingStatus : Str
        IsCurrent : Bool
    }
    class M["knowledge.EmbeddingModel"] {
        ModelID : Int32 PK
        ModelName : Str
        ModelVersion : Str
        Dimensions : Int32
        IsActive : Bool
    }
    class O["ops.IndexOutbox"] {
        EventID : Int64 PK
        SourceRevisionID : Int64 FK
        ModelID : Int32? FK
        Operation : Str
        EventStatus : Str
        AttemptCount : Int32
        LeaseUntil : DateTime?
    }
    S --> O
    M --> O
~~~

### Журнал действий

~~~mermaid
classDiagram
    direction TB
    class U["auth.UserAccount"] {
        UserID : Int64 PK
        Login : Str
        EmailNormalized : Str
        AccountStatus : Str
        PasswordHash : Bytes?
    }
    class A["ops.AuditEvent"] {
        AuditEventID : Int64 PK
        ActorUserID : Int64? FK
        EventType : Str
        EntityType : Str
        EntityID : Int64
        CorrelationID : UUID?
    }
    U --> A
~~~

**Три главные цепочки:** пользователь → сообщество → материал; материал → версия → фрагмент → сущность; вопрос → найденный фрагмент → цитата.
