# Памятка по таблицам SocialNetworkDB

Одна база SQL Server 2025: 33 таблицы в схемах `auth`, `social`, `knowledge`, `assistant` и `ops`.

**Как читать:** каждый прямоугольник — таблица, внутри видны её основные поля и типы. Стрелка показывает связь. `PK` — ключ таблицы, `FK` — ссылка на другую таблицу, `NULL` — поле допускает пустое значение; остальные перечисленные столбцы имеют `NOT NULL`. `$from_id` и `$to_id` — служебные псевдостолбцы SQL Graph: их тип не задаётся в `CREATE TABLE`. Повторяющиеся прямоугольники на разных рисунках обозначают одну и ту же таблицу. Точные SQL-типы и остальные служебные поля — в [T-SQL DDL](../database/README.md).

## 1. Пользователи и сообщества

Профиль и вход принадлежат пользователю. Подписка ведёт к другому пользователю; членство — к сообществу.

### Аккаунт, профиль и сообщество

~~~mermaid
classDiagram
    direction TB
    class U["auth.UserAccount"] {
        UserID : BIGINT PK
        Login : NVARCHAR#40;80#41;
        EmailNormalized : NVARCHAR#40;254#41;
        AccountStatus : VARCHAR#40;12#41;
        PasswordHash : VARBINARY#40;64#41; NULL
    }
    class P["auth.UserProfile"] {
        UserID : BIGINT PK FK
        DisplayName : NVARCHAR#40;120#41;
        Bio : NVARCHAR#40;1000#41; NULL
        ProfileVisibility : VARCHAR#40;8#41;
    }
    class X["auth.ExternalIdentity"] {
        FirebaseUID : NVARCHAR#40;128#41; PK
        UserID : BIGINT FK
    }
    class C["social.Community"] {
        CommunityID : BIGINT PK
        OwnerUserID : BIGINT FK
        Slug : NVARCHAR#40;100#41;
        CommunityName : NVARCHAR#40;160#41;
        Visibility : VARCHAR#40;8#41;
        Status : VARCHAR#40;12#41;
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
        UserID : BIGINT PK
        Login : NVARCHAR#40;80#41;
        EmailNormalized : NVARCHAR#40;254#41;
        AccountStatus : VARCHAR#40;12#41;
        PasswordHash : VARBINARY#40;64#41; NULL
    }
    class F["social.Follows"] {
        $from_id
        $to_id
    }
    class U2["auth.UserAccount (другой пользователь)"] {
        UserID : BIGINT PK
        Login : NVARCHAR#40;80#41;
        EmailNormalized : NVARCHAR#40;254#41;
        AccountStatus : VARCHAR#40;12#41;
        PasswordHash : VARBINARY#40;64#41; NULL
    }
    class M["social.MemberOf"] {
        MembershipID : BIGINT PK
        $from_id
        $to_id
        Role : VARCHAR#40;10#41;
        MemberStatus : VARCHAR#40;8#41;
        EndedAt : DATETIME2#40;3#41; NULL
    }
    class C["social.Community"] {
        CommunityID : BIGINT PK
        OwnerUserID : BIGINT FK
        Slug : NVARCHAR#40;100#41;
        CommunityName : NVARCHAR#40;160#41;
        Visibility : VARCHAR#40;8#41;
        Status : VARCHAR#40;12#41;
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
        UserID : BIGINT PK
        Login : NVARCHAR#40;80#41;
        EmailNormalized : NVARCHAR#40;254#41;
        AccountStatus : VARCHAR#40;12#41;
        PasswordHash : VARBINARY#40;64#41; NULL
    }
    class A["social.Authored"] {
        $from_id
        $to_id
    }
    class I["social.ContentItem"] {
        ContentID : BIGINT PK
        Kind : VARCHAR#40;8#41;
        ContentStatus : VARCHAR#40;12#41;
        AllowRag : BIT
        PublishedAt : DATETIME2#40;3#41; NULL
    }
    class P["social.PublishedIn"] {
        $from_id
        $to_id
    }
    class C["social.Community"] {
        CommunityID : BIGINT PK
        OwnerUserID : BIGINT FK
        Slug : NVARCHAR#40;100#41;
        CommunityName : NVARCHAR#40;160#41;
        Visibility : VARCHAR#40;8#41;
        Status : VARCHAR#40;12#41;
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
        ContentID : BIGINT PK
        Kind : VARCHAR#40;8#41;
        ContentStatus : VARCHAR#40;12#41;
        AllowRag : BIT
        PublishedAt : DATETIME2#40;3#41; NULL
    }
    class CO["social.CommentOn"] {
        $from_id
        $to_id
    }
    class P["social.ContentItem (POST)"] {
        ContentID : BIGINT PK
        Kind : VARCHAR#40;8#41;
        ContentStatus : VARCHAR#40;12#41;
        AllowRag : BIT
        PublishedAt : DATETIME2#40;3#41; NULL
    }
    class U["auth.UserAccount"] {
        UserID : BIGINT PK
        Login : NVARCHAR#40;80#41;
        EmailNormalized : NVARCHAR#40;254#41;
        AccountStatus : VARCHAR#40;12#41;
        PasswordHash : VARBINARY#40;64#41; NULL
    }
    class R["social.ReactTo"] {
        $from_id
        $to_id
        ReactionType : VARCHAR#40;12#41;
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
        ContentID : BIGINT PK
        Kind : VARCHAR#40;8#41;
        ContentStatus : VARCHAR#40;12#41;
        AllowRag : BIT
        PublishedAt : DATETIME2#40;3#41; NULL
    }
    class PR["social.PostRevision"] {
        RevisionID : BIGINT PK
        ContentID : BIGINT FK
        RevisionNo : INT
        Body : NVARCHAR#40;MAX#41;
        EditedByUserID : BIGINT FK
        IsCurrent : BIT
    }
    class C["social.ContentItem (COMMENT)"] {
        ContentID : BIGINT PK
        Kind : VARCHAR#40;8#41;
        ContentStatus : VARCHAR#40;12#41;
        AllowRag : BIT
        PublishedAt : DATETIME2#40;3#41; NULL
    }
    class CR["social.CommentRevision"] {
        RevisionID : BIGINT PK
        ContentID : BIGINT FK
        RevisionNo : INT
        Body : NVARCHAR#40;MAX#41;
        CommentStatus : VARCHAR#40;8#41;
        IsCurrent : BIT
    }
    P --> PR
    C --> CR
~~~

### Версии документа

~~~mermaid
classDiagram
    direction TB
    class I["social.ContentItem (DOCUMENT)"] {
        ContentID : BIGINT PK
        Kind : VARCHAR#40;8#41;
        ContentStatus : VARCHAR#40;12#41;
        AllowRag : BIT
        PublishedAt : DATETIME2#40;3#41; NULL
    }
    class D["social.DocumentDetail"] {
        ContentID : BIGINT PK FK
        Title : NVARCHAR#40;250#41;
        Description : NVARCHAR#40;2000#41; NULL
        DocumentStatus : VARCHAR#40;12#41;
    }
    class V["knowledge.DocumentVersion"] {
        DocumentVersionID : BIGINT PK
        ContentID : BIGINT FK
        VersionNo : INT
        MimeType : VARCHAR#40;127#41;
        PlainText : NVARCHAR#40;MAX#41; NULL
        FileBytes : VARBINARY#40;MAX#41; NULL
        IsCurrent : BIT
        OCRStatus : VARCHAR#40;10#41;
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
        RevisionID : BIGINT PK
        ContentID : BIGINT FK
        RevisionNo : INT
        Body : NVARCHAR#40;MAX#41;
        EditedByUserID : BIGINT FK
        IsCurrent : BIT
    }
    class C["social.CommentRevision"] {
        RevisionID : BIGINT PK
        ContentID : BIGINT FK
        RevisionNo : INT
        Body : NVARCHAR#40;MAX#41;
        CommentStatus : VARCHAR#40;8#41;
        IsCurrent : BIT
    }
    class D["knowledge.DocumentVersion"] {
        DocumentVersionID : BIGINT PK
        ContentID : BIGINT FK
        VersionNo : INT
        MimeType : VARCHAR#40;127#41;
        PlainText : NVARCHAR#40;MAX#41; NULL
        FileBytes : VARBINARY#40;MAX#41; NULL
        IsCurrent : BIT
        OCRStatus : VARCHAR#40;10#41;
    }
    class S["knowledge.SourceRevision"] {
        SourceRevisionID : BIGINT PK
        ContentID : BIGINT FK
        PostRevisionID : BIGINT FK NULL
        CommentRevisionID : BIGINT FK NULL
        DocumentVersionID : BIGINT FK NULL
        ExtractedText : NVARCHAR#40;MAX#41; NULL
        ProcessingStatus : VARCHAR#40;10#41;
        IsCurrent : BIT
    }
    class K["knowledge.Chunk"] {
        ChunkID : BIGINT PK
        SourceRevisionID : BIGINT FK
        ChunkNo : INT
        ChunkText : NVARCHAR#40;MAX#41;
        PageNo : INT NULL
        StartOffset : INT
        EndOffset : INT
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
        ChunkID : BIGINT PK
        SourceRevisionID : BIGINT FK
        ChunkNo : INT
        ChunkText : NVARCHAR#40;MAX#41;
        PageNo : INT NULL
        StartOffset : INT
        EndOffset : INT
    }
    class E["knowledge.ChunkEmbedding"] {
        ChunkID : BIGINT PK FK
        ModelID : INT PK FK
        Embedding : VECTOR#40;384#41;
    }
    class M["knowledge.EmbeddingModel"] {
        ModelID : INT PK
        ModelName : NVARCHAR#40;200#41;
        ModelVersion : NVARCHAR#40;80#41;
        Dimensions : INT
        IsActive : BIT
    }
    K --> E
    M --> E
~~~

### Упоминания в исходном материале

~~~mermaid
classDiagram
    direction TB
    class K["knowledge.Chunk"] {
        ChunkID : BIGINT PK
        SourceRevisionID : BIGINT FK
        ChunkNo : INT
        ChunkText : NVARCHAR#40;MAX#41;
        PageNo : INT NULL
        StartOffset : INT
        EndOffset : INT
    }
    class O["knowledge.ChunkOf"] {
        $from_id
        $to_id
    }
    class I["social.ContentItem"] {
        ContentID : BIGINT PK
        Kind : VARCHAR#40;8#41;
        ContentStatus : VARCHAR#40;12#41;
        AllowRag : BIT
        PublishedAt : DATETIME2#40;3#41; NULL
    }
    class M["knowledge.Mentions"] {
        MentionID : BIGINT PK
        $from_id
        $to_id
        EvidenceChunkID : BIGINT FK
        EvidenceText : NVARCHAR#40;1000#41;
        Confidence : DECIMAL#40;4,3#41;
    }
    class E["knowledge.KnowledgeEntity"] {
        EntityID : BIGINT PK
        EntityType : VARCHAR#40;14#41;
        EntityName : NVARCHAR#40;500#41;
        ExtractorVersion : NVARCHAR#40;80#41;
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
        EntityID : BIGINT PK
        EntityType : VARCHAR#40;14#41;
        EntityName : NVARCHAR#40;500#41;
        ExtractorVersion : NVARCHAR#40;80#41;
    }
    class R["knowledge.EntityRelation"] {
        RelationID : BIGINT PK
        $from_id
        $to_id
        PredicateCode : VARCHAR#40;20#41;
        EvidenceChunkID : BIGINT FK
        EvidenceText : NVARCHAR#40;1000#41;
        Confidence : DECIMAL#40;4,3#41;
    }
    class E2["knowledge.KnowledgeEntity (другая сущность)"] {
        EntityID : BIGINT PK
        EntityType : VARCHAR#40;14#41;
        EntityName : NVARCHAR#40;500#41;
        ExtractorVersion : NVARCHAR#40;80#41;
    }
    class K["knowledge.Chunk"] {
        ChunkID : BIGINT PK
        SourceRevisionID : BIGINT FK
        ChunkNo : INT
        ChunkText : NVARCHAR#40;MAX#41;
        PageNo : INT NULL
        StartOffset : INT
        EndOffset : INT
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
        UserID : BIGINT PK
        Login : NVARCHAR#40;80#41;
        EmailNormalized : NVARCHAR#40;254#41;
        AccountStatus : VARCHAR#40;12#41;
        PasswordHash : VARBINARY#40;64#41; NULL
    }
    class C["social.Community"] {
        CommunityID : BIGINT PK
        OwnerUserID : BIGINT FK
        Slug : NVARCHAR#40;100#41;
        CommunityName : NVARCHAR#40;160#41;
        Visibility : VARCHAR#40;8#41;
        Status : VARCHAR#40;12#41;
    }
    class S["assistant.RagSession"] {
        SessionID : BIGINT PK
        UserID : BIGINT FK
        CommunityID : BIGINT FK NULL
        Scope : VARCHAR#40;16#41;
    }
    class T["assistant.RagTurn"] {
        TurnID : BIGINT PK
        SessionID : BIGINT FK
        TurnNo : INT
        QuestionText : NVARCHAR#40;2000#41;
        AnswerText : NVARCHAR#40;MAX#41; NULL
        GenerationStatus : VARCHAR#40;12#41;
    }
    class F["assistant.TurnFeedback"] {
        TurnID : BIGINT PK FK
        UserID : BIGINT FK
        Rating : SMALLINT
        Comment : NVARCHAR#40;1000#41; NULL
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
        TurnID : BIGINT PK
        SessionID : BIGINT FK
        TurnNo : INT
        QuestionText : NVARCHAR#40;2000#41;
        AnswerText : NVARCHAR#40;MAX#41; NULL
        GenerationStatus : VARCHAR#40;12#41;
    }
    class R["assistant.RetrievalRun"] {
        RetrievalRunID : BIGINT PK
        TurnID : BIGINT FK
        RetrievalMode : VARCHAR#40;16#41;
        ModelVersion : NVARCHAR#40;120#41;
    }
    class K["knowledge.Chunk"] {
        ChunkID : BIGINT PK
        SourceRevisionID : BIGINT FK
        ChunkNo : INT
        ChunkText : NVARCHAR#40;MAX#41;
        PageNo : INT NULL
        StartOffset : INT
        EndOffset : INT
    }
    class F["assistant.RetrievedChunk"] {
        RetrievalRunID : BIGINT PK FK
        ChunkID : BIGINT PK FK
        Rank : INT
        Snippet : NVARCHAR#40;1000#41;
        VectorScore : DECIMAL#40;9,6#41; NULL
        TextScore : DECIMAL#40;9,6#41; NULL
        GraphScore : DECIMAL#40;9,6#41; NULL
    }
    class C["assistant.AnswerCitation"] {
        CitationID : BIGINT PK
        RetrievalRunID : BIGINT FK
        ChunkID : BIGINT FK
        QuoteText : NVARCHAR#40;1000#41;
        PageNo : INT NULL
        StartOffset : INT
        EndOffset : INT
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
        UserID : BIGINT PK
        Login : NVARCHAR#40;80#41;
        EmailNormalized : NVARCHAR#40;254#41;
        AccountStatus : VARCHAR#40;12#41;
        PasswordHash : VARBINARY#40;64#41; NULL
    }
    class B["assistant.RecommendationBatch"] {
        BatchID : BIGINT PK
        UserID : BIGINT FK
        AlgorithmVersion : NVARCHAR#40;40#41;
    }
    class I["assistant.RecommendationItem"] {
        BatchID : BIGINT PK FK
        ContentID : BIGINT PK FK
        Rank : INT
        Score : DECIMAL#40;9,6#41;
        ReasonCode : VARCHAR#40;24#41;
        ReasonText : NVARCHAR#40;500#41;
    }
    class C["social.ContentItem"] {
        ContentID : BIGINT PK
        Kind : VARCHAR#40;8#41;
        ContentStatus : VARCHAR#40;12#41;
        AllowRag : BIT
        PublishedAt : DATETIME2#40;3#41; NULL
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
        SourceRevisionID : BIGINT PK
        ContentID : BIGINT FK
        PostRevisionID : BIGINT FK NULL
        CommentRevisionID : BIGINT FK NULL
        DocumentVersionID : BIGINT FK NULL
        ExtractedText : NVARCHAR#40;MAX#41; NULL
        ProcessingStatus : VARCHAR#40;10#41;
        IsCurrent : BIT
    }
    class M["knowledge.EmbeddingModel"] {
        ModelID : INT PK
        ModelName : NVARCHAR#40;200#41;
        ModelVersion : NVARCHAR#40;80#41;
        Dimensions : INT
        IsActive : BIT
    }
    class O["ops.IndexOutbox"] {
        EventID : BIGINT PK
        SourceRevisionID : BIGINT FK
        ModelID : INT FK NULL
        Operation : VARCHAR#40;8#41;
        EventStatus : VARCHAR#40;8#41;
        AttemptCount : INT
        LeaseUntil : DATETIME2#40;3#41; NULL
    }
    S --> O
    M --> O
~~~

### Журнал действий

~~~mermaid
classDiagram
    direction TB
    class U["auth.UserAccount"] {
        UserID : BIGINT PK
        Login : NVARCHAR#40;80#41;
        EmailNormalized : NVARCHAR#40;254#41;
        AccountStatus : VARCHAR#40;12#41;
        PasswordHash : VARBINARY#40;64#41; NULL
    }
    class A["ops.AuditEvent"] {
        AuditEventID : BIGINT PK
        ActorUserID : BIGINT FK NULL
        EventType : VARCHAR#40;40#41;
        EntityType : VARCHAR#40;40#41;
        EntityID : BIGINT
        CorrelationID : UNIQUEIDENTIFIER NULL
    }
    U --> A
~~~

**Три главные цепочки:** пользователь → сообщество → материал; материал → версия → фрагмент → сущность; вопрос → найденный фрагмент → цитата.
