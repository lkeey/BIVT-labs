# Карта системы

Firebase Authentication → веб-клиент → Go API → SQL Server.
Firebase Hosting размещает статический клиент. Go API размещается отдельно.

SQL Server: реляционное ядро + один граф подписок (UserNode, Follows).
Документы хранятся вместе с версиями в реляционных таблицах.
Лента вычисляется SQL, без моделей и индексирующих сервисов.

См. [архитектуру](../docs/architecture.md) и [модель](../docs/data-model.md).
