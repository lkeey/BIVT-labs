# Курсовая работа — информационная поддержка социальной сети

Отдельный проект по проектированию базы социальной сети и интеллектуального
поиска на **SQL Server 2025 и T-SQL**. Он не использует Docker-конфигурацию из
`03SQL/docker`: та среда закреплена за SQL Server 2019 и лабораторными работами.

## Архитектурные решения

- Одна база `SocialNetworkDB` со схемами `auth`, `social`, `knowledge`,
  `assistant`, `ops` и 33 таблицами: 5 узлов и 9 рёбер SQL Graph,
  19 обычных таблиц.
- SQL Graph связывает пользователей, сообщества, публикации, документы и
  извлечённые сущности. Социальные рёбра включают подписки, членство и реакции;
  рёбра знаний указывают на проверяемые фрагменты исходного текста.
- RAG объединяет SQL Full-Text Search, точный `VECTOR_DISTANCE` и SQL Graph.
  Проверка доступа выполняется при поиске и перед передачей контекста LLM;
  цитата должна указывать на действительно найденный доступный фрагмент.
- Embeddings строятся моделью
  [`intfloat/multilingual-e5-small` на закреплённой ревизии](https://huggingface.co/intfloat/multilingual-e5-small/tree/fd1525a9fd15316a2d503bf26ab031a61d056e98)
  с размерностью 384 и хранятся в `VECTOR(384)`.
- Рекомендательная лента ранжирует доступные публикации и документы по интересам
  пользователя, социальным связям, членству, реакциям, комментариям и свежести.
  Для рекомендации показывается краткая причина.
- Исходные PDF/DOCX, извлечённый текст, фрагменты и связи с координатами
  источника хранятся в SQL. Распознавание русского текста, создание embeddings
  и финальная генерация ответа выполняются прикладными компонентами вне T-SQL.

## Структура

| Каталог | Назначение |
| --- | --- |
| [`database/`](database/README.md) | Упорядоченные T-SQL-скрипты базы, SQL Graph, ACL, RAG и рекомендаций |
| [`docs/`](docs/architecture.md) | Архитектура, ER-диаграммы и принятые решения |
| [`api/`](api/README.md) | Контракт HTTP API v1 на OpenAPI 3.1 и граница доверенного backend |
| [`backend/`](backend/README.md) | Go API: проверка Firebase ID token, социальные маршруты и SQL-процедуры |
| [`worker/`](worker/README.md) | Обработчик outbox: PDF/DOCX, русский OCR, E5 и граф с источниками |
| [`deploy/vps/`](deploy/vps/README.md) | Шаблоны systemd, окружения и HTTPS proxy для одного VPS |
| [`web/`](web/README.md) | Адаптивный JavaScript-сайт для Firebase Hosting |
| [`tools/`](tools/) | Локальная проверка HTTP-контракта, preflight Azure MI и применение T-SQL |
| [`compose.yaml`](compose.yaml) | Локальный запуск Go API, индексатора и приватного E5-сервиса при готовом SQL Server |

Диаграммы потоков и правила доступа находятся в
[`docs/architecture.md`](docs/architecture.md), каталог таблиц и ER-связи — в
[`docs/data-model.md`](docs/data-model.md). Для написания пояснительной записки
подготовлен [план глав с указанием исходного кода и демонстрационных
материалов](docs/coursework-outline.md). Постоянные правила для агентов
описаны в [`AGENTS.md`](AGENTS.md); повторяемая процедура доступна как
repo-local Skill в [`.agents/skills/sql-coursework/SKILL.md`](../.agents/skills/sql-coursework/SKILL.md).
Шаги запуска и границы бесплатного размещения описаны в
[`docs/deployment.md`](docs/deployment.md). Для публичного запуска подготовлены
[вариант с SQL Server 2025 Express на VPS](docs/vps-express.md) и отдельная
[инструкция Azure SQL Managed Instance Free](docs/azure-mi-free.md).
Для размещения без банковской карты при наличии постоянно включённого x86-64
компьютера есть [схема с Tailscale Funnel](docs/self-host.md).

## Материалы курсовой

[Архитектура и обсуждение в Google Drive](https://docs.google.com/document/d/187AqSxvD9fiTLw3ExvQa6wspBZPqk7LPda7mL57pLCg/edit?usp=drivesdk)

В исходном задании `!КДЗ_Темы.doc` для темы № 38 назначение и функции
социальной сети студент выбирает и согласует с преподавателем. Описанная здесь
реализация — проектное предложение; подтверждение согласования пока не
зафиксировано.

## Применение скриптов

Создайте отдельную пустую `SocialNetworkDB` на SQL Server 2025 с компонентом
Full-Text Search и примените скрипты 00–17 по порядку из
[`database/README.md`](database/README.md). Среда `03SQL/docker` относится к
лабораторным на SQL Server 2019.

## Локальная демонстрация

1. Разверните SQL Server 2025 с Full-Text Search и примените скрипты по
   [`database/README.md`](database/README.md). Для API и индексатора создайте
   отдельных пользователей базы с ролями `coursework_api` и
   `coursework_worker`.
2. Настройте Firebase Authentication и доверенные учётные данные backend по
   [`backend/README.md`](backend/README.md). Browser config содержит только
   публичные параметры Firebase; SQL-пароль остаётся на сервере.
3. Запустите [`worker/`](worker/README.md) с ODBC Driver 18, русским Tesseract
   и закреплённой E5-моделью. Он заполняет индекс после публикации.
4. Запустите приватный сервис embedding вопроса из того же `worker/` и
   доверенный OpenAI-совместимый endpoint модели ответа. Укажите их адреса в
   окружении Go API. При локальном запуске задайте `ADDR=:8081` и
   `CORS_ORIGIN=http://localhost:8080`: сайт из следующего шага использует
   порт 8080, а backend по умолчанию тоже слушает его.
5. Откройте сайт локально по инструкции [`web/README.md`](web/README.md)
   на `http://localhost:8080`. В форме подключения укажите
   `http://localhost:8081/api` либо запишите этот публичный адрес в
   [`web/public/config.js`](web/public/config.js).

`POST /api/v1/rag/queries` использует SQL-поиск, SQL Graph и LLM, сохраняет
ответ только с проверенными цитатами. Если модели не настроены, маршрут
возвращает `503`; лента, публикации и документы продолжают работать. Полный
контракт запросов и ответов — в [`api/openapi.yaml`](api/openapi.yaml).

Статический сайт опубликован на [Firebase Hosting](https://bivt-labs-sql-coursework.web.app/),
а Google Sign-In включён в проекте `bivt-labs-sql-coursework`. Публичные Go API,
SQL Server, worker и модели пока не размещены, поэтому функции социальной сети
на этом адресе ещё недоступны. Для демонстрации можно использовать локальный
SQL Server 2025 и [Compose-конфигурацию приложения](docs/deployment.md).
Публичное размещение требует отдельно доступных SQL Server, worker и модели;
подробности и ограничения — в [`docs/architecture.md`](docs/architecture.md).
