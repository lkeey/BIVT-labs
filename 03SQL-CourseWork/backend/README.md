# Go API курсовой

Backend связывает Firebase Authentication с реляционными данными SQL Server.
PostgreSQL остаётся совместимым демонстрационным вариантом. Оба варианта
используют одинаковый HTTP-контракт [`../api/openapi.yaml`](../api/openapi.yaml).

## Запуск

1. Создайте новую учебную БД по [`../database/README.md`](../database/README.md).
   Не применяйте новую схему поверх старой без отдельной миграции и копии данных.
2. Выдайте SQL-пользователю только роль `coursework_api`, а не права администратора.
3. Задайте окружение:

| Переменная | Назначение |
| --- | --- |
| `SQLSERVER_DSN` | SQL Server DSN с проверкой TLS-сертификата |
| `POSTGRES_DSN` или `DATABASE_URL` | Альтернатива SQL Server; не задавайте оба типа БД одновременно |
| `FIREBASE_PROJECT_ID` | `bivt-labs-sql-coursework` для существующего проекта |
| `FIREBASE_WEB_API_KEY` | Публичный Web API key того же проекта из `web/public/config.js` |
| `CORS_ORIGIN` | Точный HTTPS origin сайта; локально `http://localhost:8080` |
| `ADDR` / `PORT` | Адрес API; локально `ADDR=:8081`, чтобы не занять порт сайта |
| `MAX_DOCUMENT_BYTES` | От 1 до 10485760, по умолчанию 10 МиБ; учитывайте лимит хостинга |

Из этого каталога:

```sh
go mod download
go run .
```

Секреты БД храните вне Git. Ни worker, ни модель, ни API генерации не нужны.
`GET /healthz` проверяет процесс; `GET /readyz` проверяет соединение с БД.
Маршруты `/api/v1` требуют `Authorization: Bearer <Firebase ID token>`.

## Firebase и безопасность

Сервер проверяет RS256-подпись по опубликованным ключам Google, `aud`, `iss`,
срок действия и время входа. Затем `accounts:lookup` проверяет блокировку и
отзыв токена. Ошибка Firebase закрывает доступ. Только проверенный UID
передаётся в `auth.usp_GetOrCreateFirebaseUser`; числовой ID из запроса
никогда не задаёт личность вызывающего. Ключ service account не нужен.

Unsigned-токены Firebase emulator намеренно не принимаются production API.
Для независимой демонстрации Firebase используйте `web/public/firebase-demo.html`.
Публичный API пока не заявляется настроенным: `backendReady` остаётся false
до проверки реального размещения. Состояние провайдера и доменов необходимо
проверить владельцу в Firebase Console перед показом преподавателю.

## Поведение

- CRUD сообществ, членство, подписки, посты, комментарии, реакции и модерация.
- Документы сохраняются сразу, возвращают `201` и `processingStatus: READY`.
  PDF/DOCX остаются оригинальными файлами в SQL. OCR и индексирования нет.
- Публикация возвращает `contentId` и `revisionId`.
- `social.usp_BuildRecommendationFeed` строит ленту из доступных материалов
  по подпискам, членству и времени; ответы RAG отсутствуют.
- Приватность проверяется SQL при каждом чтении и скачивании.

## Проверки

```sh
go test ./...
go vet ./...
go build ./...
python3 ../tools/verify_contract.py
```

Unit-тесты проверяют удаление AI-маршрутов, обязательность авторизации,
Firebase-подпись, чужой проект, просроченные/отозванные токены и блокировку.
Они не заменяют запуск SQL и настоящий Google popup.
