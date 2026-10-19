# Публичная демонстрация на VPS с SQL Server 2025 Express

Целевой вариант: один **x86-64 VPS с Ubuntu 24.04**, установленным SQL Server
2025 Express, Go API, русскоязычным OCR/E5 worker и приватным сервисом
embedding. [Сайт](https://bivt-labs-sql-coursework.web.app/) остаётся на
Firebase Hosting. Это самостоятельно администрируемый сервер, а не управляемая
база. Инструкция не означает, что VPS или API уже развёрнуты.

## Выбор сервера и лицензии

- До начала нужны аккаунт хостинга, оплаченный VPS, SSH-ключ и доступ к DNS.
  Например, [OVHcloud VPS-3](https://www.ovhcloud.com/en/vps/) предлагает
  6 vCore, 12 ГБ RAM, 100 ГБ NVMe и выделенный IPv4 **от $12,32/мес при
  годовой предоплате**. Помесячная цена, налоги и доступность зависят от
  региона; точную сумму смотрите в корзине. Размещение на VPS платное, даже
  если лицензия SQL Server Express бесплатная. Хостинг может потребовать обычную проверку
  аккаунта или способа оплаты; подтверждение статуса студента не требуется.
- [Минимум SQL Server на Linux](https://learn.microsoft.com/en-us/sql/linux/install-upgrade/setup?view=sql-server-ver17):
  x64, 2 ядра по 2 ГГц, 2 ГБ RAM для запуска самого SQL Server, 6 ГБ
  свободного места, файловая система ext4 или XFS. Эти значения **не**
  включают Go API, Tesseract, E5, кеш модели, документы и резервные копии.
  Для всего стека 12 ГБ RAM — практичная стартовая оценка, которую надо
  подтвердить замерами. При локальной LLM разумнее выбрать больше памяти,
  например 24 ГБ, или использовать внешний endpoint.
- [SQL Server 2025 Express](https://learn.microsoft.com/en-us/sql/sql-server/editions-and-components-of-sql-server-2025?view=sql-server-ver17)
  разрешён для небольших рабочих приложений и поддерживает SQL Graph,
  Full-Text Search и тип `VECTOR`. Его ограничения: одна база не более
  50 ГБ, до 4 ядер на экземпляр, 1410 МБ buffer pool, нет SQL Server Agent
  и сжатия резервных копий. Бесплатная Developer edition лицензирована
  только для разработки и тестирования, поэтому для публичного сайта
  используйте Express. Приближённый векторный индекс требует preview;
  скрипты курсовой используют точный `VECTOR_DISTANCE`.
- Контейнеры SQL Server поддерживаются только на x86-64 Linux, не на ARM
  или эмуляции. Ubuntu 24.04 поддерживается для SQL Server 2025
  [по документации Microsoft](https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-release-notes-2025?view=sql-server-ver17).

## Порядок развёртывания

1. Создайте x86-64 VPS с Ubuntu 24.04 и SSH-ключом. Включите обновления ОС,
   отдельного непривилегированного пользователя приложения и firewall.
   Входящие соединения: `443/tcp` для API, `80/tcp` для получения TLS
   сертификата, `22/tcp` только с адреса администратора. **Не открывайте**
   `1433/tcp`, `8765/tcp` и внутренний порт Go API для Интернета. Разместите
   SQL и прикладные процессы на одном хосте. Для доступа к SQL с рабочего
   компьютера используйте SSH tunnel, а не публичный SQL-порт.
2. Добавьте официальный репозиторий `mssql-server-2025` для Ubuntu 24.04,
   установите `mssql-server` по
   [инструкции Microsoft](https://learn.microsoft.com/en-us/sql/linux/install-upgrade/quickstart-install-ubuntu?view=sql-server-ver17).
   В `/opt/mssql/bin/mssql-conf setup` выберите **Express**, задайте сильный
   пароль `sa` и сохраните его вне репозитория. Установите отдельный пакет
   `mssql-server-fts` по
   [инструкции Full-Text](https://learn.microsoft.com/en-us/sql/linux/install-upgrade/setup-full-text-search?view=sql-server-ver17).
   Ограничьте прослушивание SQL loopback через
   `sudo /opt/mssql/bin/mssql-conf set network.ipaddress 127.0.0.1` и
   перезапустите `mssql-server`; этот параметр описан в
   [документации Microsoft](https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-configure-mssql-conf?view=sql-server-ver17).
   Установите `sqlcmd`; убедитесь, что версия движка — 17.x, редакция —
   Express, а запросы ниже возвращают `1` и строку Russian/1049:

   ```sql
   SELECT @@VERSION, SERVERPROPERTY('Edition');
   SELECT FULLTEXTSERVICEPROPERTY('IsFullTextInstalled');
   SELECT name, lcid FROM sys.fulltext_languages WHERE lcid = 1049;
   ```

   Русский word breaker входит в SQL Server 2025 на Linux, но пакет FTS
   устанавливается отдельно. Если FTS не готов, `06-indexes.sql` остановит
   установку схемы. Для бинарных PDF/DOCX курсовая извлекает текст в worker;
   системные FTS-фильтры этих форматов SQL не требуются.
3. Настройте [TLS-сертификат SQL Server на Linux](https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-encrypted-connections?view=sql-server-ver17)
   и доверие к нему у Go драйвера и ODBC Driver 18; в строках подключения оставьте `Encrypt=yes`
   и `TrustServerCertificate=no`. Создайте пустую `SocialNetworkDB`,
   примените `database/00`–`database/17` **по порядку** через `sqlcmd -b -I`
   и остановитесь при первой ошибке. Подробности — в
   [database/README.md](../database/README.md). Создайте разные SQL-логины
   для `coursework_api` и `coursework_worker`, добавьте соответствующих
   пользователей базы в роли из скрипта 17. Работающие сервисы не должны
   входить как `sa`.
4. Подготовьте Firebase Authentication проекта `bivt-labs-sql-coursework` и
   Firebase Admin credential JSON только для Go API. Сохраните его **вне Git**
   с правами `0600`; SQL-пароли, токен embedding-сервиса и ключ LLM храните
   в секретах сервера с доступом лишь служебным пользователям. Переменные
   приведены в [`.env.example`](../.env.example). Для соединений через
   `localhost` сертификат SQL должен содержать `localhost` в SAN, а его
   удостоверяющий центр должен быть доверенным и для Go, и для ODBC-клиента.
5. Установите Go для [backend](../backend/README.md), Python 3.11+, ODBC
   Driver 18, Tesseract и русский пакет `tesseract-ocr-rus` для
   [worker](../worker/README.md). Подготовьте отдельные процессы API,
   `index_worker.py --loop --poll-seconds 10` и `embed_service.py` под
   системным менеджером служб с автозапуском и ограничениями памяти.
   Для Go API задайте `ADDR=127.0.0.1:8081`, `SQLSERVER_DSN`,
   `GOOGLE_APPLICATION_CREDENTIALS` и `FIREBASE_PROJECT_ID` по инструкции
   backend; worker получает свою отдельную ODBC-строку подключения.
   Закреплённую E5-модель загрузите в постоянный `HF_HOME` до приёма
   документов; для индексации и вопроса должна использоваться одна ревизия
   модели и размерность 384. Приватный embedding-сервис слушает
   `127.0.0.1:8765`; на одном хосте доступ ограничен loopback. Если сервис
   вынесен в приватную сеть, задайте ему и Go API одинаковый случайный Bearer
   токен длиной не менее 32 символов.
   Для размещения всех процессов на одном хосте подготовлены
   [unit-файлы systemd, образцы окружения и Caddyfile](../deploy/vps/README.md).
   Их loopback embedding-сервис не требует Bearer-токен.
6. Для полного RAG задайте `CHAT_COMPLETIONS_URL` и `CHAT_MODEL`. Внешний
   OpenAI-совместимый endpoint должен использовать HTTPS и иметь право
   получать тексты доступных пользователю фрагментов. Альтернатива —
   небольшая локальная LLM с OpenAI-совместимым HTTP API, доступным **только
   по loopback**; производительность и качество на CPU нужно оценить на
   выбранной VM. Без настроенной модели маршрут RAG вернёт `503`, хотя
   остальные функции API продолжат работать.
7. Настройте DNS-имя API на выделенный IPv4 и HTTPS reverse proxy (например,
   Caddy) к Go API на `127.0.0.1:8081`. Таймаут proxy должен превышать
   100 секунд: синхронный RAG-запрос может занимать до 90 секунд. Ограничьте
   число одновременных запросов. `CORS_ORIGIN` задайте **точно** как
   `https://bivt-labs-sql-coursework.web.app`. После проверки публичного
   `GET /healthz`, `GET /readyz`, входа через Firebase и сценария с цитатами
   обновите `web/public/config.js` на HTTPS API и `backendReady: true`, затем
   переопубликуйте сайт. Браузер не получает SQL-строку подключения,
   Firebase Admin credential или ключ LLM.

`compose.yaml` предназначен для локального запуска прикладных контейнеров.
На Linux он **не является готовым VPS-рецептом**: SQL Server и модель ответа
в нём отсутствуют, а `host.docker.internal` в примере DSN может не
разрешаться. Для этого runbook выбран запуск SQL и приложений на одном хосте;
если переходить на Compose, сначала явно настройте внутреннюю сеть и адрес
SQL, сохранив запрет публичного доступа к портам базы и worker.

## Эксплуатация

- Для Express планируйте `BACKUP DATABASE` через системный таймер вместо SQL
  Server Agent. Храните зашифрованную копию **за пределами VPS**, задайте
  срок хранения и периодически проверяйте восстановление в отдельной базе.
  Снимок самой VM полезен, но не заменяет независимую резервную копию БД.
- Обновляйте ОС, SQL Server и приложения; следите за заполнением диска,
  памятью, статусом служб и очередью `ops.IndexOutbox`. Файл `.env`, JSON
  Firebase Admin, бэкапы и кеш модели не включайте в PR.
- Стоимость внешней LLM, домена и внешних бэкапов не входит в цену VPS.
  Публичный запуск пока не подтверждён; включайте `backendReady` только после
  проверки конечного пользовательского сценария.
