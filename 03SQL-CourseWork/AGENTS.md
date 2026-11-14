# Курсовая по SQL Server

Это самостоятельный проект SQL Server 2025/T-SQL. PostgreSQL-вариант в
`database/postgres/` служит совместимой демонстрацией, не заменяя T-SQL.

- Основная модель реляционная. Допустимы только две SQL Graph таблицы:
  `social.UserNode` и `social.Follows`. Не возвращать RAG/embeddings/LLM.
- Синхронно меняйте SQL-процедуры, Go API и `api/openapi.yaml`.
- Firebase UID сопоставляет с UserID только backend после проверки токена.
- Сохраняйте ACL, документы и версии; не сбрасывайте существующую БД.
- Для изменений данных используйте тестовую БД и транзакции с ROLLBACK.
- Обновляйте README и модель. Запускайте проверки из README; отдельно
  сообщайте о реальном выполнении SQL Server/PostgreSQL и облачного Firebase.
