# База данных курсовой: что мы храним и как связаны записи

**Предметная область:** социальная сеть с сообществами, постами, комментариями и документами. Вопросы по материалам и рекомендательная лента используют те же данные. Для курсовой есть **одна база SocialNetworkDB на SQL Server 2025** с пятью схемами: auth, social, knowledge, assistant и ops. Всего в ней **33 таблицы**: 5 узлов SQL Graph, 9 рёбер и 19 обычных таблиц.

Здесь показаны **важные поля каждой модели и реальные пары полей для соединения**. Число таблиц в заголовке раздела считает каждую модель один раз; повторённые для контекста узлы в него не входят. Указаны не все технические столбцы; их типы и ограничения находятся в [T-SQL-скриптах](../database/README.md). API и хостинг в этом документе не рассматриваются.

## Как читать стрелки

- **PK → FK:** например, UserAccount.UserID = UserProfile.UserID. В прямоугольниках эти поля помечены PK и FK.
- **UNIQUE → составной FK:** SourceRevision указывает на редакцию по паре (ContentID, RevisionID); пара уникальна, хотя PK редакции — только RevisionID.
- **SQL Graph:** у узла есть обычный PK и созданный SQL Server системный $node_id. Ребро хранит $from_id и $to_id и соединяется с $node_id узлов. Поэтому у MemberOf **нет** поля UserID, по которому его можно было бы связать с пользователем. Обход выполняется через MATCH.
- Подпись на каждой стрелке показывает именно сравниваемые поля. Mermaid проводит линию между прямоугольниками, а не к отдельной строке внутри них.

## 1. Учётные записи и сообщества · 6 таблиц

~~~mermaid
flowchart TB
    U["auth.UserAccount · NODE<br/>PK UserID · $node_id<br/>Login · EmailNormalized · AccountStatus"]
    P["auth.UserProfile<br/>PK/FK UserID<br/>DisplayName · ProfileVisibility"]
    X["auth.ExternalIdentity<br/>PK FirebaseUID · FK/UNIQUE UserID"]
    C["social.Community · NODE<br/>PK CommunityID · $node_id<br/>FK OwnerUserID · Visibility"]
    M["social.MemberOf · EDGE<br/>PK MembershipID · $from_id · $to_id<br/>Role · MemberStatus · EndedAt"]
    F["social.Follows · EDGE<br/>$from_id · $to_id · CreatedAt<br/>без PK; UNIQUE пара концов"]
    U2["auth.UserAccount: другой пользователь<br/>PK UserID · $node_id"]

    U -->|"PK UserID = PK/FK UserID"| P
    U -->|"PK UserID = FK/UNIQUE UserID"| X
    U -->|"PK UserID = FK OwnerUserID"| C
    U -->|"$node_id = $from_id"| M
    M -->|"$to_id = $node_id"| C
    U -->|"$node_id = $from_id"| F
    F -->|"$to_id = $node_id"| U2
~~~

UserAccount хранит логин, нормализованный email и статус аккаунта; UserProfile — публичные сведения. ExternalIdentity привязывает проверенный Firebase UID, причём один аккаунт имеет не более одной такой привязки. Community хранит владельца обычным FK, а членство — графовым ребром MemberOf со статусом и ролью. Follows — направленная подписка на другого пользователя; она влияет на ленту, но не открывает закрытое сообщество.

Для чтения закрытого сообщества нужен владелец или действующее членство ACTIVE. Заявка PENDING доступа не даёт; актуальные BLOCKED/BANNED закрывают даже открытые материалы.

## 2. Социальные связи публикации · 5 таблиц

~~~mermaid
flowchart TB
    U["auth.UserAccount · NODE<br/>PK UserID · $node_id"]
    P["social.ContentItem: POST · NODE<br/>PK ContentID · $node_id<br/>Kind · ContentStatus · AllowRag"]
    CM["social.ContentItem: COMMENT · NODE<br/>PK ContentID · $node_id<br/>Kind · ContentStatus"]
    C["social.Community · NODE<br/>PK CommunityID · $node_id"]
    A["social.Authored · EDGE<br/>$from_id · $to_id<br/>без PK; UNIQUE $to_id"]
    PI["social.PublishedIn · EDGE<br/>$from_id · $to_id<br/>без PK; UNIQUE $from_id"]
    CO["social.CommentOn · EDGE<br/>$from_id · $to_id<br/>без PK; UNIQUE $from_id"]
    RT["social.ReactTo · EDGE<br/>$from_id · $to_id · ReactionType<br/>без PK; UNIQUE пара концов"]
    U -->|"$node_id = $from_id"| A
    A -->|"$to_id = $node_id"| P
    P -->|"$node_id = $from_id"| PI
    PI -->|"$to_id = $node_id"| C
    CM -->|"$node_id = $from_id"| CO
    CO -->|"$to_id = $node_id"| P
    U -->|"$node_id = $from_id"| RT
    RT -->|"$to_id = $node_id"| P
~~~

ContentItem — общая запись с видом POST, COMMENT или DOCUMENT, состоянием DRAFT/PUBLISHED/HIDDEN/DELETED и флагом AllowRag. **Автор и сообщество не дублируются в его столбцах:** их задают Authored и PublishedIn. Диаграмма показывает пост и комментарий как две строки одной таблицы. У документа тоже есть Authored и PublishedIn; у комментария есть Authored, а сообщество он наследует от родительского поста по CommentOn. ReactTo хранит вид реакции LIKE, HELPFUL или INSIGHTFUL.

Ограничение CONNECTION проверяет, что концы рёбер принадлежат нужным таблицам. Правило «CommentOn ведёт от COMMENT к POST» проверяют процедуры: обе строки являются ContentItem, и тип Kind системное графовое ограничение не различает. Рёбра Follows, Authored, PublishedIn, CommentOn, ReactTo и ChunkOf не имеют отдельного PK; уникальные индексы ограничивают допустимые пары или один из концов.

## 3. Текст и версии публикаций · 4 таблицы

~~~mermaid
flowchart TB
    I["social.ContentItem · NODE<br/>PK ContentID · Kind"]
    U["auth.UserAccount<br/>PK UserID"]
    PR["social.PostRevision<br/>PK RevisionID · FK ContentID · FK EditedByUserID<br/>RevisionNo · Body · IsCurrent"]
    CR["social.CommentRevision<br/>PK RevisionID · FK ContentID<br/>RevisionNo · Body · CommentStatus · IsCurrent"]
    DD["social.DocumentDetail<br/>PK/FK ContentID<br/>Title · DocumentStatus"]
    DV["knowledge.DocumentVersion<br/>PK DocumentVersionID · FK ContentID<br/>VersionNo · PlainText ИЛИ FileBytes · IsCurrent<br/>MimeType · SizeBytes · SHA256 · OCRStatus"]

    I -->|"PK ContentID = FK ContentID; Kind POST"| PR
    I -->|"PK ContentID = FK ContentID; Kind COMMENT"| CR
    I -->|"PK ContentID = PK/FK ContentID; Kind DOCUMENT"| DD
    U -->|"PK UserID = FK EditedByUserID"| PR
    DD -->|"PK ContentID = FK ContentID"| DV
~~~

Пост и комментарий получают новую строку редакции после правки; история остаётся. У документов заголовок и состояние обработки лежат в DocumentDetail, а содержимое — в DocumentVersion. Одна версия документа содержит **либо** PlainText, **либо** PDF/DOCX в FileBytes VARBINARY(MAX); ограничение SizeBytes действует и на текст, и на файл, максимум 10 МиБ. Фильтрованные UNIQUE-индексы допускают только одну текущую редакцию каждого материала.

Поля RevisionID и DocumentVersionID — PK отдельных версий; ContentID привязывает все версии к одному материалу. Для защиты полезно отличать **материал** ContentItem от **его конкретной редакции**.

## 4. Снимок для поиска и векторы · 4 таблицы

Один SourceRevision указывает **ровно на одну** редакцию: поста, комментария или документа. Его CHECK требует, чтобы из трёх FK был заполнен ровно один. Эти FK составные: вместе с ID редакции они включают ContentID, поэтому снимок нельзя случайно связать с редакцией другого материала.

~~~mermaid
flowchart TB
    PR["social.PostRevision<br/>UNIQUE (ContentID, RevisionID)"]
    CR["social.CommentRevision<br/>UNIQUE (ContentID, RevisionID)"]
    DV["knowledge.DocumentVersion<br/>UNIQUE (ContentID, DocumentVersionID)"]
    I["social.ContentItem<br/>PK ContentID"]
    SR["knowledge.SourceRevision<br/>PK SourceRevisionID · FK ContentID<br/>FK PostRevisionID / CommentRevisionID / DocumentVersionID<br/>IsCurrent · ProcessingStatus · ExtractedText"]

    PR -->|"UNIQUE (ContentID,RevisionID) = FK (ContentID,PostRevisionID)"| SR
    CR -->|"UNIQUE (ContentID,RevisionID) = FK (ContentID,CommentRevisionID)"| SR
    DV -->|"UNIQUE (ContentID,DocumentVersionID) = FK (ContentID,DocumentVersionID)"| SR
    I -->|"PK ContentID = FK ContentID"| SR
~~~

Три стрелки к SourceRevision — **альтернативы**, а не три одновременных источника. После индексации его текст разбивается на фрагменты. Для каждого фрагмента сохраняются текст, страница и позиции символов; отдельная таблица хранит вектор и версию модели.

~~~mermaid
flowchart TB
    SR["knowledge.SourceRevision<br/>PK SourceRevisionID · ProcessingStatus"]
    K["knowledge.Chunk · NODE<br/>PK ChunkID · FK SourceRevisionID · $node_id<br/>ChunkText · PageNo · StartOffset · EndOffset"]
    V["knowledge.ChunkEmbedding<br/>PK (ChunkID, ModelID)<br/>FK ChunkID · FK ModelID · Embedding VECTOR(384)"]
    M["knowledge.EmbeddingModel<br/>PK ModelID<br/>ModelName · ModelVersion · Dimensions"]

    SR -->|"PK SourceRevisionID = FK SourceRevisionID"| K
    K -->|"PK ChunkID = PK/FK ChunkID"| V
    M -->|"PK ModelID = PK/FK ModelID"| V
~~~

EmbeddingModel фиксирует конкретную версию multilingual-e5-small и размерность 384. ChunkEmbedding может хранить вектор для пары «фрагмент + модель». OCR и создание вектора выполняет внешний обработчик; SQL Server хранит результаты. Поиск использует только текущие готовые снимки и фрагменты. По словам работает Full-Text Search, по близости смысла — VECTOR_DISTANCE.

## 5. Граф знаний и проверяемое свидетельство · 4 таблицы

~~~mermaid
flowchart TB
    K["knowledge.Chunk · NODE<br/>PK ChunkID · $node_id<br/>ChunkText · PageNo · StartOffset · EndOffset"]
    I["social.ContentItem · NODE<br/>PK ContentID · $node_id"]
    E1["knowledge.KnowledgeEntity · NODE<br/>PK EntityID · $node_id<br/>EntityType · EntityName"]
    E2["knowledge.KnowledgeEntity: другая сущность<br/>PK EntityID · $node_id"]
    OF["knowledge.ChunkOf · EDGE<br/>$from_id · $to_id; без PK<br/>UNIQUE $from_id"]
    ME["knowledge.Mentions · EDGE<br/>PK MentionID · $from_id · $to_id<br/>FK EvidenceChunkID · EvidenceText · StartOffset · EndOffset · Confidence"]
    ER["knowledge.EntityRelation · EDGE<br/>PK RelationID · $from_id · $to_id<br/>FK EvidenceChunkID · PredicateCode · EvidenceText · Confidence"]

    K -->|"$node_id = $from_id"| OF
    OF -->|"$to_id = $node_id"| I
    K -->|"$node_id = $from_id"| ME
    ME -->|"$to_id = $node_id"| E1
    K -.->|"PK ChunkID = FK EvidenceChunkID"| ME
    E1 -->|"$node_id = $from_id"| ER
    ER -->|"$to_id = $node_id"| E2
    K -.->|"PK ChunkID = FK EvidenceChunkID"| ER
~~~

KnowledgeEntity хранит извлечённую тему, человека, организацию, событие или место. Похожие имена автоматически не объединяются. Mentions показывает, где сущность упомянута; EntityRelation хранит тип связи, например WORKS_AT, и ссылку на Chunk, в котором найдено свидетельство. У обоих рёбер есть координаты, исходная выдержка, уверенность и версия извлекателя.

Здесь одновременно действуют **два вида связи**: системные Graph-концы показывают, какие узлы соединены, а обычный FK EvidenceChunkID показывает, каким текстом подтверждается утверждение. Без доступа к этому фрагменту нельзя использовать связь в ответе.

## 6. Вопрос, поиск и цитата · 6 таблиц

~~~mermaid
flowchart TB
    U["auth.UserAccount<br/>PK UserID"]
    C["social.Community<br/>PK CommunityID"]
    S["assistant.RagSession<br/>PK SessionID · FK UserID · FK CommunityID?<br/>Scope"]
    T["assistant.RagTurn<br/>PK TurnID · FK SessionID<br/>QuestionText · AnswerText · GenerationStatus"]
    R["assistant.RetrievalRun<br/>PK RetrievalRunID · FK TurnID<br/>RetrievalMode · ModelVersion"]
    K["knowledge.Chunk<br/>PK ChunkID"]
    RC["assistant.RetrievedChunk<br/>PK (RetrievalRunID, ChunkID)<br/>FK RetrievalRunID · FK ChunkID<br/>Rank · Snippet · TextScore · VectorScore · GraphScore"]
    AC["assistant.AnswerCitation<br/>PK CitationID · FK (RetrievalRunID, ChunkID)<br/>QuoteText · PageNo · StartOffset · EndOffset"]
    F["assistant.TurnFeedback<br/>PK/FK TurnID · FK UserID<br/>Rating · Comment"]

    U -->|"PK UserID = FK UserID"| S
    C -.->|"PK CommunityID = FK CommunityID, если задан"| S
    S -->|"PK SessionID = FK SessionID"| T
    T -->|"PK TurnID = FK TurnID"| R
    R -->|"PK RetrievalRunID = PK/FK RetrievalRunID"| RC
    K -->|"PK ChunkID = PK/FK ChunkID"| RC
    RC -->|"PK (RetrievalRunID,ChunkID) = FK (RetrievalRunID,ChunkID)"| AC
    T -->|"PK TurnID = PK/FK TurnID"| F
    U -->|"PK UserID = FK UserID"| F
~~~

RagSession задаёт пользователя и область поиска: все доступные сообщества или одно выбранное. RagTurn хранит вопрос, ответ и состояние. RetrievalRun фиксирует настройки поиска; RetrievedChunk — **фактически выбранные** фрагменты и их оценки. AnswerCitation ссылается составным FK именно на пару ключей RetrievedChunk. Процедура дополнительно сверяет текст цитаты с символами доступного Chunk и его координатами. Это подтверждает происхождение цитаты, но не гарантирует правильность всех выводов модели.

При чтении сохранённого ответа SQL снова проверяет доступ к источникам. TurnFeedback хранит необязательную оценку 1–5: не более одной на ход.

## 7. Рекомендации и служебные записи · 4 таблицы

~~~mermaid
flowchart TB
    U["auth.UserAccount<br/>PK UserID"]
    B["assistant.RecommendationBatch<br/>PK BatchID · FK UserID<br/>AlgorithmVersion · CreatedAt"]
    RI["assistant.RecommendationItem<br/>PK (BatchID, ContentID)<br/>FK BatchID · FK ContentID<br/>Rank · Score · ReasonCode · ReasonText"]
    I["social.ContentItem<br/>PK ContentID"]
    SR["knowledge.SourceRevision<br/>PK SourceRevisionID"]
    M["knowledge.EmbeddingModel<br/>PK ModelID"]
    O["ops.IndexOutbox<br/>PK EventID · FK SourceRevisionID · FK ModelID?<br/>Operation · EventStatus · AttemptCount · LeaseUntil"]
    A["ops.AuditEvent<br/>PK AuditEventID · FK ActorUserID?<br/>EventType · EntityType · EntityID · CorrelationID · OccurredAt"]

    U -->|"PK UserID = FK UserID"| B
    B -->|"PK BatchID = PK/FK BatchID"| RI
    I -->|"PK ContentID = PK/FK ContentID"| RI
    SR -->|"PK SourceRevisionID = FK SourceRevisionID"| O
    M -.->|"PK ModelID = FK ModelID, если задан"| O
    U -.->|"PK UserID = FK ActorUserID, если задан"| A
~~~

RecommendationBatch — один расчёт ленты для пользователя. RecommendationItem хранит конкретный пост или документ, ранг, оценку 0..1 и причину. Формула учитывает темы/сущности (0,30), подписку на автора (0,25), членство (0,20), реакции и комментарии (0,15), свежесть (0,10). Комментарии служат сигналом интереса, но не являются элементами ленты. Перед выдачей проверяется текущий доступ к материалу.

IndexOutbox — очередь переиндексации после появления SourceRevision: операция UPSERT/DELETE, состояние, число попыток и аренда обработчика. Триггер добавляет задание в транзакции записи, а тяжёлая обработка происходит позже. AuditEvent фиксирует действие, объект, время, корреляционный ID и необязательного пользователя; там не хранятся пароли и полные документы. Пара (EntityType, EntityID) обозначает объект разных типов, поэтому общего FK на одну целевую таблицу у журнала нет.

## Один документ проходит через модель

Допустим, Анна публикует в закрытом сообществе PDF с фразой «Иван работает в лаборатории Спектр».

1. Права на публикацию определяются UserAccount, Community и действующим MemberOf. Создаётся ContentItem вида DOCUMENT; Authored и PublishedIn связывают его с Анной и сообществом.
2. DocumentDetail хранит заголовок, DocumentVersion — байты PDF. SourceRevision указывает на эту версию, IndexOutbox ставит задачу обработки.
3. После извлечения текста появляются Chunk с текстом и координатами, ChunkEmbedding с вектором и ChunkOf с указанием материала.
4. Если извлекатель распознал «Иван» и «Спектр», появляются KnowledgeEntity, Mentions и EntityRelation(WORKS_AT). EvidenceChunkID указывает на фрагмент со словами, из которых выведена связь.
5. При вопросе «Где работает Иван?» найденный фрагмент фиксируется в RetrievedChunk. AnswerCitation может указать только этот доступный фрагмент и дословную выдержку. Пользователь без доступа к закрытому сообществу не получает ни фрагмент, ни сохранённый ответ.
6. После редактирования или скрытия документа старые версии остаются для истории, но не участвуют в новом поиске.

## Что говорить на защите

- **Почему одна база и пять схем?** Схемы разделяют предметные области внутри SocialNetworkDB; FK и транзакции работают в одной базе.
- **Что здесь является источником истины?** Аккаунты, сообщества, материалы, их версии и социальные связи. Снимки поиска, векторы и извлечённый граф — производные данные.
- **Зачем SQL Graph?** Он хранит направленные социальные и предметные связи с атрибутами. При этом обычные таблицы и FK остаются для версий, ключей и истории.
- **Что происходит при редактировании?** Создаётся новая редакция и новый SourceRevision; старое содержание не используется для новых ответов.
- **Чем отличаются текст, вектор и граф?** Текст даёт слова и цитату, вектор — близость смысла, граф — явные связи между объектами.
- **Как проверяется цитата?** FK требует, чтобы Chunk был в сохранённой выдаче; процедура сверяет цитату с его текстом и позициями и повторно проверяет права.
- **Что делает SQL, а что вне него?** SQL хранит данные, ограничения, права, поиск и очередь; OCR, embeddings и генерацию ответа выполняют внешние компоненты.

Точные типы, ограничения, индексы и порядок применения находятся в [канонических T-SQL-скриптах](../database/README.md).
