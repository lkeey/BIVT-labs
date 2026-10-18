# HTTP API курсовой

Go-сервер соединяет [веб-клиент](../web/README.md) с процедурами SQL Server 2025.
Браузер получает Firebase ID token; сервер проверяет подпись, срок действия,
проект и отзыв через Firebase Admin SDK. После проверки `UID` сопоставляется с
`auth.UserAccount` через `auth.usp_GetOrCreateFirebaseUser`. Пользовательский
`UserID` из JSON и URL никогда не служит личностью вызывающего.

## Подготовка

1. Примените скрипты из [database/README.md](../database/README.md), включая
   `15-api-reads.sql`, `16-index-worker.sql`, `17-auth-and-roles.sql`. Для
   `06-indexes.sql` нужен установленный SQL Server Full-Text Search.
2. Создайте отдельного пользователя базы для backend и добавьте его в роль
   `coursework_api`. Не используйте `sa` и не выдавайте роли прямых прав на
   таблицы. Изолируйте SQL Server от публичного Интернета; серверу нужен
   сетевой доступ к нему по TLS с проверкой сертификата.
3. Настройте Firebase Auth и проект. Локально предоставьте Firebase Admin SDK
   Application Default Credentials через `GOOGLE_APPLICATION_CREDENTIALS`
   (путь к файлу вне репозитория). На хостинге используйте защищённый секрет
   или штатную identity платформы.
4. Установите переменные окружения:

| Переменная | Назначение |
| --- | --- |
| `SQLSERVER_DSN` | Строка подключения `sqlserver://user:password@host:1433?database=SocialNetworkDB&encrypt=true&TrustServerCertificate=false` |
| `FIREBASE_PROJECT_ID` | Идентификатор именно того Firebase-проекта, чьи токены принимаются |
| `CORS_ORIGIN` | Точный HTTPS origin веб-сайта, например `https://coursework.web.app`; при локальном запуске по инструкции сайта — `http://localhost:8080` |
| `ADDR` | Адрес прослушивания, по умолчанию `:8080` |
| `EMBEDDING_SERVICE_URL` | Приватный URL сервиса из [worker/embed_service.py](../worker/README.md#приватный-сервис-вектора-вопроса), например `http://127.0.0.1:8765/embed` |
| `EMBEDDING_SERVICE_TOKEN` | Необязательный Bearer секрет сервиса вектора; соответствует его `COURSEWORK_EMBED_BEARER_TOKEN` |
| `CHAT_COMPLETIONS_URL` | Доверенный OpenAI-совместимый маршрут, например `http://127.0.0.1:11434/v1/chat/completions` |
| `CHAT_MODEL` | Название доступной модели ответа, максимум 120 символов |
| `CHAT_API_KEY` | Необязательный Bearer ключ модели ответа; для локального Ollama может отсутствовать |
| `CHAT_HEALTH_URL` | Необязательный GET-маршрут доступности; по умолчанию выводится `/v1/models` из `CHAT_COMPLETIONS_URL` |

Секреты держите в окружении хостинга или локальном файле вне Git. Проверка
токена с отзывом делает сетевой запрос к Firebase на каждом HTTP-запросе.
Сервис embedding и модель ответа получают текст вопроса; модель ответа также
получает до пяти цитат из доступных материалов. Используйте собственный
доверенный endpoint или провайдера, которому можно передавать эти данные.
Для HTTP без TLS код допускает только `localhost` или буквальный приватный IP.
Для остальных адресов требуется HTTPS. `CHAT_HEALTH_URL` должен иметь тот же
origin, что `CHAT_COMPLETIONS_URL`, поскольку проверка передаёт ключ модели.

## Запуск

Из этой папки:

```sh
go mod download
go run .
```

Если `go` недоступен в `PATH`, в Arcadia-окружении работает `ya tool go run .`.
Для контейнера предусмотрен [Dockerfile](Dockerfile).

Для одновременного локального запуска сайта на `http://localhost:8080`
и API задайте `ADDR=:8081` и `CORS_ORIGIN=http://localhost:8080`
при запуске backend. В `web/public/config.js` укажите
`apiBaseUrl: "http://localhost:8081/api"`. URL HTTP разрешён клиентом только
для localhost; остальные обязательные переменные окружения остаются нужны.

`GET /healthz` проверяет процесс, `GET /readyz` проверяет SQL Server. Основные
маршруты начинаются с `/api/v1`; к ним нужен заголовок
`Authorization: Bearer <Firebase ID token>`.

## Реализованные маршруты

| Раздел | Маршруты |
| --- | --- |
| Личность | `GET /auth/sessions/current`, `GET /users/{userId}` |
| Сообщества | `GET, POST /communities`, `GET /communities/{communityId}`, `GET, POST /communities/{communityId}/memberships`, `PATCH /communities/{communityId}/memberships/{userId}`, `DELETE /communities/{communityId}/memberships/current` |
| Подписки | `PUT, DELETE /users/{userId}/follow` |
| Контент | `GET, POST /communities/{communityId}/posts`, `GET, PATCH, DELETE /posts/{postId}`, `GET, POST /posts/{postId}/comments`, `GET, PATCH, DELETE /comments/{commentId}`, `PUT, DELETE /content/{contentId}/reaction`, `PUT /content/{contentId}/moderation/hide` |
| Документы | `GET, POST /communities/{communityId}/documents`, `GET /documents/{documentId}`, `POST /documents/{documentId}/versions`, `GET /documents/{documentId}/file` |
| Помощник | `GET /feed`, `POST /rag/queries`, `GET /rag/queries/{queryId}` |

Полный контракт и схемы ответов описаны в [OpenAPI](../api/openapi.yaml).
Большие SQL `bigint` передаются в JSON как строки, курсор страницы —
URL-safe Base64 от последнего ID. Все чтения материалов выполняются через
процедуры, которые проверяют текущие права и актуальную редакцию. `GET /feed`
получает объяснимый рейтинг из SQL Graph.

Загрузка документа принимает JSON `{ "title": "...", "text": "..." }` или
`multipart/form-data` с полями `title` и `file` (PDF/DOCX). Максимум 10 МиБ.
Статус `PROCESSING` сменится только после работы отдельного индексатора.

`POST /rag/queries` сверяет доступность обоих сервисов до записи запроса в
SQL. Если они не настроены или недоступны, возвращает **503
`RAG_UNAVAILABLE`** без создания хода. При работающих сервисах backend:

1. Получает закреплённый 384-мерный `query:`-вектор из приватного embedding
   сервиса и проверяет имя модели, SHA ревизии, размерность и норму.
2. Создаёт SQL-сессию и ход, запускает гибридный поиск с графовыми именами
   вопроса. SQL фильтрует источники по текущим правам пользователя.
3. Повторно фиксирует максимум пять доступных фрагментов через
   `assistant.usp_RecordRetrievedChunks`; только после этого передаёт их
   модели ответа. Тексты материалов рассматриваются как данные, не инструкции.
4. Проверяет ссылки `[1]`…`[5]` в ответе: ответ без ссылок, с неверным номером
   или повреждённым форматом отвергается. Сохраняет только упомянутые цитаты
   из точных подстрок с исходными координатами.
   `assistant.usp_SaveRagAnswer` сверяет цитаты и права ещё раз. Если
   источников нет, сохраняет `NO_SOURCES` без вызова модели ответа; при сбое
   отмечает ход как `FAILED`.

Маршрут дожидается завершения обработки (до 90 секунд) и затем возвращает
`201` с `queryId`, текущим статусом и заголовком `Location`; веб-клиент читает результат через
`GET /rag/queries/{queryId}`. Для хостинга нужен HTTP timeout больше 100
секунд. Сейчас нет отдельной долговечной очереди генерации, поэтому после
обрыва процесса между созданием хода и записью результата возможен ход
`PENDING` до ручного восстановления. Число одновременно выполняемых запросов
ограничивайте на входном reverse proxy.

`GET /rag/queries/{queryId}` повторно проверяет все источники; при отзыве
доступа возвращает 410 без текста ответа и цитат. Обмен токена на собственную
сессию (`POST /auth/sessions`) и серверный logout не реализованы: Firebase
ID token передаётся как Bearer на каждом запросе, а клиент при выходе
удаляет его из памяти и завершает Firebase-сессию.

## Проверка

```sh
go build ./...
go vet ./...
```

Сборка и статический анализ проверяют Go-код; проверка маршрутов с живой БД
требует SQL Server 2025 с Full-Text Search, применённых миграций и Firebase
Auth проекта. Контейнерный образ из `Dockerfile` здесь отдельно не проверялся.
