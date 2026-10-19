# Запуск прикладных процессов на одном VPS

Эти файлы дополняют [инструкцию установки SQL Server 2025 Express](../../docs/vps-express.md).
Они рассчитаны на Ubuntu 24.04, SQL Server на этом же хосте и отдельное
HTTPS-имя API. До запуска нужны готовая база `SocialNetworkDB`, два SQL-логина
с ролями `coursework_api` и `coursework_worker`, сертификат SQL для `localhost`,
Firebase Admin credential и доступная модель ответа. Ни один пример с
`REPLACE_` не является рабочим секретом.

## Размещение файлов

Операции выполняются из корня клона репозитория после получения нужного
коммита. Установите Go версии из
[`backend/go.mod`](../../backend/go.mod), Python 3.11+, Python venv, ODBC
Driver 18, `tesseract-ocr`, `tesseract-ocr-rus` и Caddy. Пакеты SQL Server и
Full-Text ставятся отдельно по основной инструкции. Системные пользователи
не имеют права входа и собственного домашнего каталога:

```sh
sudo useradd --system --no-create-home --shell /usr/sbin/nologin coursework-api
sudo useradd --system --no-create-home --shell /usr/sbin/nologin coursework-index
sudo useradd --system --no-create-home --shell /usr/sbin/nologin coursework-embed
sudo install -d -m 0755 /opt/sql-coursework /opt/sql-coursework/bin /etc/sql-coursework
git archive --format=tar HEAD 03SQL-CourseWork/backend 03SQL-CourseWork/worker | sudo tar -xf - -C /opt/sql-coursework --strip-components=1
go -C /opt/sql-coursework/backend build -o /tmp/coursework-api .
sudo install -m 0755 /tmp/coursework-api /opt/sql-coursework/bin/coursework-api
sudo python3 -m venv /opt/sql-coursework/venv
sudo /opt/sql-coursework/venv/bin/python -m pip install -r /opt/sql-coursework/worker/requirements.txt
```

Команды создания пользователей выполняются один раз. При обновлении кода
повторите копирование исходников, сборку и перезапуск изменённых служб;
`git archive` переносит только файлы коммита и не копирует локальные секреты.

Создайте файлы окружения из `*.env.example` в `/etc/sql-coursework/`. Для
`api.env` задайте `root:coursework-api`, для `index.env` —
`root:coursework-index`, для `embed.env` — `root:coursework-embed`; режим каждого
файла — `0640`, каталог `/etc/sql-coursework` — `0755`. Замените все примеры
паролей и имён модели. Firebase Admin JSON разместите в
`/etc/sql-coursework/firebase-admin.json` с владельцем
`root:coursework-api` и режимом `0640`. Не печатайте секреты в истории shell
или журнале. Сертификат, которому доверяют Go и ODBC, должен соответствовать
`localhost` в SAN; `TrustServerCertificate` остаётся `false` / `no`.

`embed_service.py` слушает только `127.0.0.1:8765`, поэтому в этой схеме
Bearer-токен ему не нужен. Оба Python-процесса скачивают закреплённую E5-модель
в собственные системные кеши. Это дублирует модель на диске, зато у
индексатора нет доступа к файлам embedding-сервиса и наоборот. Модель
предварительно загрузите до приёма документов, если исходящий доступ к
Hugging Face на сервере ограничен.

## Службы и HTTPS

После заполнения окружения установите unit-файлы и включите службы:

```sh
sudo install -m 0644 03SQL-CourseWork/deploy/vps/coursework-api.service /etc/systemd/system/
sudo install -m 0644 03SQL-CourseWork/deploy/vps/coursework-index.service /etc/systemd/system/
sudo install -m 0644 03SQL-CourseWork/deploy/vps/coursework-embed.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now coursework-embed coursework-index coursework-api
```

Установите [`Caddyfile.example`](Caddyfile.example) как Caddyfile и замените
`api.example.com` реальным DNS-именем, указывающим на VPS. Разрешите входящие
80/443; Caddy самостоятельно получает публичный TLS-сертификат. Перед
перезапуском проверьте `caddy validate --config /etc/caddy/Caddyfile`.
`reverse_proxy` оставляет путь `/api/v1/...` без изменений и ждёт ответ
дольше максимальных 90 секунд RAG-маршрута. SQL (1433), Go API (8081),
embedding (8765) и локальная LLM (если есть) доступны лишь через loopback.
Задайте `network.ipaddress=127.0.0.1` для SQL Server через `mssql-conf` и
перезапустите его; дополнительно запретите внешний 1433 в firewall хостинга.

Если используется локальный Ollama, установите его как отдельную службу,
загрузите выбранную модель и слушайте только `127.0.0.1:11434`. Пример
`api.env` направляет запросы на его OpenAI-совместимый маршрут. Подберите
модель по фактическому объёму RAM и проверьте доступность `/v1/models`.
Внешняя LLM требует HTTPS endpoint и отдельного ключа в `api.env`.

Публичную конфигурацию [сайта](../../web/public/config.js) переключайте на
новый API только после того, как `GET /healthz`, `GET /readyz`, аутентификация
Firebase, публикация с индексацией и RAG-ответ с цитатами работают на
реальном адресе. До этого `backendReady` должен оставаться `false`.
