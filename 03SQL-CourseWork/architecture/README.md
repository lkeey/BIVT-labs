# Архитектура курсовой на одной странице

**Тема:** информационная поддержка социальной сети. Каноническая реализация — одна база **SocialNetworkDB** на **SQL Server 2025 и T-SQL**. В ней 5 схем и 33 таблицы: 5 узлов SQL Graph, 9 рёбер и 19 обычных таблиц. Отдельная PostgreSQL-копия обслуживает публичную демонстрацию и не синхронизирует данные с SQL Server.

Эта страница даёт общую карту для чтения и защиты. Точные определения находятся в [T-SQL-скриптах](../database/README.md), полный HTTP-контракт — в [OpenAPI](../api/openapi.yaml), подробные правила — в [архитектурном описании](../docs/architecture.md), обсуждение проекта — в [Google Drive](https://docs.google.com/document/d/187AqSxvD9fiTLw3ExvQa6wspBZPqk7LPda7mL57pLCg/edit?usp=drivesdk).

## Система

~~~mermaid
flowchart LR
    U["Пользователь"] --> W["JavaScript-сайт<br/>Firebase Hosting"]
    W --> F["Firebase Auth"]
    F -->|"ID token"| W
    W -->|"HTTPS + Bearer token"| A["Go API"]
    A --> D[("SocialNetworkDB<br/>SQL Server 2025")]
    D -->|"ops.IndexOutbox"| P["Python worker<br/>PDF/DOCX, русский OCR, E5"]
    P -->|"текст, векторы, граф"| D
    A --> E["Сервис embedding вопроса"]
    A --> L["LLM: ответ с цитатами"]
~~~

Браузер обращается только к API. Backend проверяет Firebase ID token, получает внутренний UserID и вызывает разрешённые SQL-процедуры. Worker и API имеют разные роли без прямого доступа к базовым таблицам. Для публичной копии тот же API выбирает PostgreSQL через серверную строку подключения.

## Все таблицы

Обозначения: **NODE** — узел SQL Graph, **EDGE** — ребро SQL Graph, **TABLE** — обычная таблица. Префикс до точки — схема внутри одной базы, а не отдельная база.

| Схема | NODE | EDGE | TABLE | Всего |
| --- | --- | --- | --- | ---: |
| auth | UserAccount | — | UserProfile, ExternalIdentity | 3 |
| social | Community, ContentItem | Follows, MemberOf, Authored, PublishedIn, CommentOn, ReactTo | PostRevision, CommentRevision, DocumentDetail | 11 |
| knowledge | Chunk, KnowledgeEntity | ChunkOf, Mentions, EntityRelation | DocumentVersion, SourceRevision, EmbeddingModel, ChunkEmbedding | 9 |
| assistant | — | — | RagSession, RagTurn, RetrievalRun, RetrievedChunk, AnswerCitation, TurnFeedback, RecommendationBatch, RecommendationItem | 8 |
| ops | — | — | IndexOutbox, AuditEvent | 2 |
| **Итого** | **5** | **9** | **19** | **33** |

ContentItem.Kind различает пост, комментарий и документ. Их редактируемое содержание хранится в отдельных редакциях; SourceRevision привязывает к индексу ровно одну редакцию. Исторические редакции остаются для аудита, а поиск использует только текущие опубликованные материалы.

<details>
<summary><strong>Полная схема связей всех 33 таблиц</strong> — раскрыть ER-диаграмму</summary>

В именах диаграммы подчёркивание заменяет точку: social_ContentItem = social.ContentItem. Сплошные линии показывают основные внешние ключи; пунктирные линии с пометкой GRAPH показывают концы SQL Graph-рёбер. GRAPH-связь не является обычным FK на бизнес-идентификаторы. Диаграмма показывает структуру, а точные ограничения и кардинальности задают SQL-скрипты.

~~~mermaid
erDiagram
    auth_UserAccount ||--o| auth_UserProfile : "профиль"
    auth_UserAccount ||--o| auth_ExternalIdentity : "Firebase UID"
    auth_UserAccount ||--o{ social_Community : "владелец"
    auth_UserAccount ||--o{ social_PostRevision : "редактор"
    auth_UserAccount ||--o{ assistant_RagSession : "вопросы"
    auth_UserAccount ||--o{ assistant_RecommendationBatch : "лента"
    auth_UserAccount ||--o{ assistant_TurnFeedback : "отзыв"
    auth_UserAccount ||--o{ ops_AuditEvent : "актор"

    social_ContentItem ||--o{ social_PostRevision : "версии поста"
    social_ContentItem ||--o{ social_CommentRevision : "версии комментария"
    social_ContentItem ||--o| social_DocumentDetail : "документ"
    social_ContentItem ||--o{ knowledge_SourceRevision : "источник"
    social_ContentItem ||--o{ assistant_RecommendationItem : "рекомендован"
    social_DocumentDetail ||--o{ knowledge_DocumentVersion : "версии файла"
    social_PostRevision ||--o| knowledge_SourceRevision : "вариант источника"
    social_CommentRevision ||--o| knowledge_SourceRevision : "вариант источника"
    knowledge_DocumentVersion ||--o| knowledge_SourceRevision : "вариант источника"
    knowledge_SourceRevision ||--o{ knowledge_Chunk : "фрагменты"
    knowledge_SourceRevision ||--o{ ops_IndexOutbox : "индексация"
    knowledge_Chunk ||--o{ knowledge_ChunkEmbedding : "векторы"
    knowledge_EmbeddingModel ||--o{ knowledge_ChunkEmbedding : "модель"
    knowledge_EmbeddingModel ||--o{ ops_IndexOutbox : "модель задания"

    assistant_RagSession ||--o{ assistant_RagTurn : "ходы"
    assistant_RagTurn ||--o{ assistant_RetrievalRun : "поиски"
    assistant_RagTurn ||--o| assistant_TurnFeedback : "оценка"
    assistant_RetrievalRun ||--o{ assistant_RetrievedChunk : "выдача"
    knowledge_Chunk ||--o{ assistant_RetrievedChunk : "найден"
    assistant_RetrievedChunk ||--o{ assistant_AnswerCitation : "цитата"
    assistant_RecommendationBatch ||--o{ assistant_RecommendationItem : "элементы"

    auth_UserAccount ||..o{ social_Follows : "GRAPH от/к"
    auth_UserAccount ||..o{ social_MemberOf : "GRAPH от"
    social_Community ||..o{ social_MemberOf : "GRAPH к"
    auth_UserAccount ||..o{ social_Authored : "GRAPH от"
    social_ContentItem ||..o{ social_Authored : "GRAPH к"
    social_ContentItem ||..o{ social_PublishedIn : "GRAPH от"
    social_Community ||..o{ social_PublishedIn : "GRAPH к"
    social_ContentItem ||..o{ social_CommentOn : "GRAPH от/к"
    auth_UserAccount ||..o{ social_ReactTo : "GRAPH от"
    social_ContentItem ||..o{ social_ReactTo : "GRAPH к"
    knowledge_Chunk ||..o{ knowledge_ChunkOf : "GRAPH от"
    social_ContentItem ||..o{ knowledge_ChunkOf : "GRAPH к"
    knowledge_Chunk ||..o{ knowledge_Mentions : "GRAPH от"
    knowledge_KnowledgeEntity ||..o{ knowledge_Mentions : "GRAPH к"
    knowledge_KnowledgeEntity ||..o{ knowledge_EntityRelation : "GRAPH от/к"
    knowledge_Chunk ||--o{ knowledge_EntityRelation : "свидетельство"
~~~

У SourceRevision три необязательных FK на PostRevision, CommentRevision и DocumentVersion, но CHECK разрешает ровно один из них. AnswerCitation ссылается на действительно выданный RetrievedChunk того же поиска. Для графовых рёбер точные направления и допустимые типы концов перечислены ниже.

</details>

### Девять рёбер SQL Graph

| Ребро | От → к | Смысл |
| --- | --- | --- |
| social.Follows | UserAccount → UserAccount | Подписка |
| social.MemberOf | UserAccount → Community | Членство, роль и статус |
| social.Authored | UserAccount → ContentItem | Авторство |
| social.PublishedIn | ContentItem → Community | Публикация |
| social.CommentOn | ContentItem → ContentItem | Комментарий к посту |
| social.ReactTo | UserAccount → ContentItem | Реакция |
| knowledge.ChunkOf | Chunk → ContentItem | Фрагмент исходного материала |
| knowledge.Mentions | Chunk → KnowledgeEntity | Упоминание в тексте |
| knowledge.EntityRelation | KnowledgeEntity → KnowledgeEntity | Извлечённая связь со свидетельством |

KnowledgeEntity — упоминание темы, человека, организации, события или места; одинаковые имена автоматически не объединяются. EntityRelation хранит EvidenceChunkID, координаты, Confidence и версию извлекателя. Для поиска годятся только связи с доступным пользователю исходным фрагментом.

## Форматы и правила доступа

| Что хранится | Где и в каком виде |
| --- | --- |
| PDF/DOCX | DocumentVersion.FileBytes: VARBINARY(MAX), SHA-256 и метаданные |
| Текст постов, комментариев, документов | NVARCHAR(MAX) в редакциях и Chunk; страница и позиции фрагмента отдельными полями |
| Embeddings | ChunkEmbedding.Embedding: VECTOR(384), ссылка на EmbeddingModel |
| Социальные и предметные связи | SQL Graph AS NODE/AS EDGE; публичные ID — обычные столбцы |
| История ответа и цитаты | RagSession → RagTurn → RetrievalRun → RetrievedChunk → AnswerCitation |

Открытый материал видит активный пользователь, если он не заблокирован в сообществе. Закрытый материал видит владелец или активный участник; заявка PENDING доступа не даёт. Комментарий наследует доступ от поста. Поиск, лента и выдача сохранённой цитаты повторно проверяют текущую редакцию и права; AllowRag = 0 сразу исключает материал из ответа.

## Потоки поиска и рекомендаций

~~~mermaid
flowchart LR
    S["Пост / комментарий / документ"] --> R["Текущая SourceRevision"]
    R --> O["IndexOutbox"]
    O --> W["Worker: текст, русский OCR, фрагменты, E5, граф"]
    W --> C["Chunk + VECTOR(384) + свидетельства"]
    Q["Вопрос"] --> H["Full-Text + VECTOR_DISTANCE + SQL Graph"]
    C --> H
    H --> ACL["Проверка доступа и актуальности"]
    ACL --> L["LLM, максимум 5 фрагментов"]
    L --> A["Ответ + проверенные цитаты"]
    C --> FEED["Лента постов и документов"]
~~~

Для векторов используется закреплённая модель multilingual-e5-small (384 измерения): текст индексируется с префиксом passage:, вопрос — с query:. Итоговый ответ создаёт внешняя LLM; SQL отвечает за поиск, происхождение цитаты и права. Лента ранжирует доступные посты и документы по темам/сущностям (0,30), подписке на автора (0,25), членству (0,20), реакциям/комментариям (0,15) и свежести (0,10). Это заданное правило, а не обученная рекомендательная модель; для каждого элемента сохраняется причина.

<details>
<summary><strong>Контракт HTTP API v1</strong> — раскрыть маршруты и форматы</summary>

Базовый путь — /api/v1. Все прикладные маршруты требуют Firebase Bearer ID token; /healthz и /readyz — исключения. Числовые SQL bigint ID в JSON передаются строками, время — UTC RFC 3339, страницы — items и nextCursor. Код 404 одинаков для отсутствующего и недоступного объекта.

| Раздел | Маршруты |
| --- | --- |
| Личность | GET /auth/sessions/current; GET /users/{userId} |
| Сообщества | GET, POST /communities; GET /communities/{communityId}; GET, POST /communities/{communityId}/memberships; PATCH /communities/{communityId}/memberships/{userId}; DELETE /communities/{communityId}/memberships/current |
| Подписки | PUT, DELETE /users/{userId}/follow |
| Контент | GET, POST /communities/{communityId}/posts; GET, PATCH, DELETE /posts/{postId}; GET, POST /posts/{postId}/comments; GET, PATCH, DELETE /comments/{commentId}; PUT, DELETE /content/{contentId}/reaction; PUT /content/{contentId}/moderation/hide |
| Документы | GET, POST /communities/{communityId}/documents; GET /documents/{documentId}; POST /documents/{documentId}/versions; GET /documents/{documentId}/file |
| Помощник | GET /feed; POST /rag/queries; GET /rag/queries/{queryId} |

Публикация документа принимает текст либо PDF/DOCX, отвечает 202 и переходит из PROCESSING в READY/FAILED после индексации. RAG возвращает 201 с цитатами или NO_SOURCES; без модели — 503. При отзыве доступа к источнику сохранённый ответ возвращает 410 без текста. Полные поля запросов, ответов и коды ошибок — в [api/openapi.yaml](../api/openapi.yaml).

</details>

## Источники истины и состояние

| Вопрос | Где смотреть |
| --- | --- |
| Таблицы, индексы, SQL Graph, процедуры | [database/README.md](../database/README.md) и T-SQL 00–17 |
| Подробные ограничения и ER | [docs/data-model.md](../docs/data-model.md) |
| ACL, индексация, RAG и лента | [docs/architecture.md](../docs/architecture.md) |
| API и обработчик | [api/openapi.yaml](../api/openapi.yaml), [backend/README.md](../backend/README.md), [worker/README.md](../worker/README.md) |
| Публичная PostgreSQL-копия | [docs/postgres-demo.md](../docs/postgres-demo.md) |

Код и контракты находятся в репозитории. По текущей документации статический сайт опубликован, а публичные API, worker и LLM ещё требуют настройки для сквозной демонстрации. Для защиты канонической базой остаётся SQL Server 2025.
