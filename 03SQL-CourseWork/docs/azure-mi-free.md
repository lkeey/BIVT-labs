# Azure SQL Managed Instance Free для курсовой

Это инструкция по развёртыванию **одной** базы курсовой на Azure SQL Managed
Instance (MI) с бесплатной моделью `Freemium` и политикой формата
`SQLServer2025`. MI — управляемый сервис, а не установленный на виртуальной
машине SQL Server 2025. Перед подключением приложения нужно применить скрипты
00–17 и проверить на MI именно функции, используемые проектом: SQL Graph,
русский Full-Text Search и `VECTOR(384)`/`VECTOR_DISTANCE`. Успешная проверка
скриптов на отдельном SQL Server 2025 не доказывает их работу на MI.

Команды ниже **не запускались в Azure**. Они предназначены для выполнения
после оформления подписки; результат создания и стоимость нужно проверить
до подключения остальных компонентов. Не сохраняйте реальные значения
паролей, строк подключения или токенов в репозитории. Все команды запускайте
из каталога `03SQL-CourseWork/` в доверенной shell-сессии без `set -x`.

## Лимиты и расходы до создания

[Бесплатное предложение MI](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/free-offer?view=azuresql-mi)
включает один экземпляр на подходящую подписку, 4 vCore, 720 vCore-часов в
месяц, 64 ГБ хранилища и действует 12 месяцев. При 4 vCore это максимум
**180 часов работы в месяц**, а не круглосуточная база. Часть 64 ГБ занимают
системные файлы. По умолчанию экземпляр включается по будням с 09:00 до 17:00
в настроенном часовом поясе; без настройки используется UTC. При исчерпании
квоты он останавливается. После 12 месяцев экземпляр останавливается, а без
перехода на платный вариант через 30 дней удаляется вместе с базами. У
бесплатного предложения нет гарантированного SLA.

Microsoft указывает, что сам экземпляр MI не создаёт дополнительных начислений
до добровольного перехода на платный тариф. Это **не обещание нулевой стоимости
всей системы**: хостинг API, worker и LLM, а также отдельные сетевые сервисы
оцениваются отдельно. [VNet бесплатна, но VPN Gateway и peering
тарифицируются](https://azure.microsoft.com/en-us/pricing/details/virtual-network/).
Следующие шаги не создают VM, VPN, NAT Gateway, peering или Private Endpoint.
Перед запуском сверьте выбранную подписку и смету в Azure Portal; не заменяйте
`Freemium` на `Regular` при ошибке доступности предложения.

## 1. Вход и только читающая проверка

Установите актуальный [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
или откройте Azure Cloud Shell. Войдите интерактивно, выберите подписку и
регион с поддержкой MI. Замените угловые скобки собственными значениями.

```bash
az login
export COURSEWORK_SUBSCRIPTION_ID='<subscription-id>'
export COURSEWORK_LOCATION='eastus'
az account set --subscription "$COURSEWORK_SUBSCRIPTION_ID"
az account show --query '{id:id,name:name,state:state}' --output table
COURSEWORK_SUBSCRIPTION_ID="$COURSEWORK_SUBSCRIPTION_ID" \
  COURSEWORK_LOCATION="$COURSEWORK_LOCATION" \
  bash tools/azure-mi-preflight.sh
```

`tools/azure-mi-preflight.sh` выполняет только чтение: проверяет выбранную
подписку, регистрацию провайдеров, видимость региона, наличие уже созданного `Freemium`
экземпляра и поддержку параметров текущей Azure CLI. Пустой список MI не
гарантирует право на бесплатное предложение: окончательную проверку делает
Azure при `az sql mi create`. При ошибке preflight сначала исправьте причину;
не продолжайте создание по инерции. Если провайдер не зарегистрирован, его
можно зарегистрировать командами `az provider register --namespace
Microsoft.Sql` и `az provider register --namespace Microsoft.Network`, затем
повторить preflight. Видимость региона в подписке не доказывает доступность MI
в нём: проверьте её в [списке поддерживаемых
регионов](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/region-availability?view=azuresql-mi).

## 2. Отдельная сеть для MI

[MI требует](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/connectivity-architecture-overview?view=azuresql-mi)
выделенную подсеть минимум с 32 адресами, делегирование
`Microsoft.Sql/managedInstances`, связанные NSG и route table. `/24` ниже даёт
запас адресов; используйте **непересекающийся** с вашей сетью диапазон.
Держите все ресурсы курсовой в отдельной группе, чтобы их было легко
инвентаризировать. Не удаляйте группу целиком, если в неё позже добавлены
чужие ресурсы.

```bash
export COURSEWORK_RG='bivt-sql-coursework-rg'
export COURSEWORK_VNET='bivt-sql-coursework-vnet'
export COURSEWORK_SUBNET='ManagedInstances'
export COURSEWORK_NSG='bivt-sql-coursework-nsg'
export COURSEWORK_ROUTE='bivt-sql-coursework-routes'

az group create --name "$COURSEWORK_RG" --location "$COURSEWORK_LOCATION" --output none
az network vnet create --resource-group "$COURSEWORK_RG" \
  --name "$COURSEWORK_VNET" --location "$COURSEWORK_LOCATION" \
  --address-prefixes 10.42.0.0/16 --subnet-name "$COURSEWORK_SUBNET" \
  --subnet-prefixes 10.42.0.0/24 --output none
az network nsg create --resource-group "$COURSEWORK_RG" \
  --name "$COURSEWORK_NSG" --location "$COURSEWORK_LOCATION" --output none
az network route-table create --resource-group "$COURSEWORK_RG" \
  --name "$COURSEWORK_ROUTE" --location "$COURSEWORK_LOCATION" --output none
az network vnet subnet update --resource-group "$COURSEWORK_RG" \
  --vnet-name "$COURSEWORK_VNET" --name "$COURSEWORK_SUBNET" \
  --network-security-group "$COURSEWORK_NSG" \
  --route-table "$COURSEWORK_ROUTE" --output none
az network vnet subnet update --resource-group "$COURSEWORK_RG" \
  --vnet-name "$COURSEWORK_VNET" --name "$COURSEWORK_SUBNET" \
  --delegations Microsoft.Sql/managedInstances --output none
export COURSEWORK_SUBNET_ID="$(az network vnet subnet show \
  --resource-group "$COURSEWORK_RG" --vnet-name "$COURSEWORK_VNET" \
  --name "$COURSEWORK_SUBNET" --query id --output tsv)"
```

Делегирование запускает [service-aided network
configuration](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/subnet-service-aided-configuration-enable?view=azuresql-mi):
Azure добавляет обязательные правила и маршруты. Не удаляйте их вручную.
Создание NSG и route table до делегирования соответствует сетевым требованиям
MI. Подсеть не должна содержать другие ресурсы.

## 3. Создание только бесплатного MI

[Azure CLI поддерживает](https://learn.microsoft.com/en-us/cli/azure/sql/mi?view=azure-cli-latest)
`--pricing-model Freemium` и `--database-format SQLServer2025`. Последний
параметр необходим явно: [для нового MI через CLI по умолчанию может
использоваться формат SQL Server 2022](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/update-policy?view=azuresql-mi).
Задайте уникальное имя MI и SQL-администратора. Пароль вводится скрытым
запросом, не сохраняется в файле или истории shell и удаляется из переменной
сразу после вызова. **Ограничение Azure CLI:** при передаче
`--admin-password` значение на короткое время присутствует в аргументах
процесса; выполняйте эту команду в доверенной однопользовательской среде, не
включайте `set -x`/`--debug` и не записывайте вывод с секретами.

```bash
export COURSEWORK_MI='<globally-unique-mi-name>'
export COURSEWORK_SQL_ADMIN='coursework_admin'
read -r -s -p 'SQL MI admin password: ' COURSEWORK_SQL_ADMIN_PASSWORD
printf '\n'
az sql mi create --subscription "$COURSEWORK_SUBSCRIPTION_ID" \
  --resource-group "$COURSEWORK_RG" --name "$COURSEWORK_MI" \
  --location "$COURSEWORK_LOCATION" --subnet "$COURSEWORK_SUBNET_ID" \
  --admin-user "$COURSEWORK_SQL_ADMIN" \
  --admin-password "$COURSEWORK_SQL_ADMIN_PASSWORD" \
  --capacity 4 --tier GeneralPurpose --family Gen5 --storage 64 \
  --license-type LicenseIncluded --backup-storage-redundancy Local \
  --pricing-model Freemium --gpv2 true \
  --database-format SQLServer2025 --public-data-endpoint-enabled true \
  --output none
unset COURSEWORK_SQL_ADMIN_PASSWORD
```

Если команда завершилась ошибкой, выполните `unset
COURSEWORK_SQL_ADMIN_PASSWORD` вручную до повторной попытки. Не добавляйте
платные параметры или `--pricing-model Regular`. После создания проверьте
**фактические** свойства:

```bash
az sql mi show --subscription "$COURSEWORK_SUBSCRIPTION_ID" \
  --resource-group "$COURSEWORK_RG" --name "$COURSEWORK_MI" \
  --query '{state:state,provisioningState:provisioningState,pricingModel:pricingModel,databaseFormat:databaseFormat,publicEndpoint:publicDataEndpointEnabled,fqdn:fullyQualifiedDomainName}' \
  --output json
```

Продолжайте только после `pricingModel=Freemium`,
`databaseFormat=SQLServer2025` и успешного завершения развёртывания. Само
значение `Freemium` не доказывает отсутствие расходов на другие ресурсы.

## 4. Ограниченный доступ к SQL

У бесплатного MI [публичный endpoint включён по
умолчанию](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/free-offer?view=azuresql-mi),
его порт — **3342**, а приватный VNet endpoint использует **1433**.
Публичный endpoint сам по себе не означает открытый вход через NSG.
Разрешите порт 3342 только с текущего внешнего IP рабочей машины; для
удалённого backend добавьте его **фиксированный** egress IP отдельным правилом.
Не используйте `0.0.0.0/0`. Если у платформы backend нет фиксированного egress,
понадобится приватное подключение или другой вариант размещения; его стоимость
следует оценить отдельно.

```bash
export COURSEWORK_ADMIN_CIDR='<your-public-ip>/32'
az network nsg rule create --resource-group "$COURSEWORK_RG" \
  --nsg-name "$COURSEWORK_NSG" --name allow-coursework-admin-sql \
  --priority 1300 --direction Inbound --access Allow --protocol Tcp \
  --source-address-prefixes "$COURSEWORK_ADMIN_CIDR" \
  --source-port-ranges '*' --destination-address-prefixes '*' \
  --destination-port-ranges 3342 --output none
```

Если публичный доступ не нужен, [отключите
его](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/public-endpoint-configure?view=azuresql-mi)
через `az sql mi update ... --public-data-endpoint-enabled false` и удалите
своё правило 3342; тогда запуск SQL-скриптов и сервисов требует доступа к VNet.
Используйте DNS-имя endpoint и TLS с проверкой сертификата, а не IP-адрес или
`TrustServerCertificate=true`.

## 5. База, скрипты и отдельные роли

Получите публичное DNS-имя по полю `fullyQualifiedDomainName`, добавив
метку `.public.` перед DNS-зоной, или скопируйте готовый Endpoint на странице
**Networking** в Azure Portal. Запишите его как `<mi-public-fqdn>,3342` для
`sqlcmd`; для Go DSN нужен тот же FQDN и порт `3342`. Не угадывайте DNS-зону.
На машине с разрешённым IP установите `sqlcmd` с ODBC Driver 18. Скрипт
запросит пароль скрыто, если `SQLCMDPASSWORD` не задана. Пароль не передаётся
через `-P` и не хранится в Git. Работайте из `03SQL-CourseWork/`:

```bash
export COURSEWORK_SQL_ENDPOINT='<mi-public-fqdn>,3342'
bash tools/apply-azure-mi-database.sh
```

Скрипт проверяет наличие всех 18 файлов и завершится ненулевым кодом при
первой ошибке SQL. Ключ `-Nm` требует шифрования, а отсутствие `-C`
сохраняет проверку TLS-сертификата. Для проверки шифрования соединения выполните
`SELECT encrypt_option FROM sys.dm_exec_connections WHERE session_id = @@SPID;`:
ожидается `TRUE`. Скрипт 06 проверяет Full-Text. Для реального подтверждения
совместимости на MI отдельно выполните поиск через
`assistant.usp_SearchRag`, запись/чтение SQL Graph и `VECTOR_DISTANCE`, а
также проверку ACL закрытого сообщества. В этом репозитории сценарии описаны
в [database/README.md](../database/README.md); факт успешной проверки на MI
пока не зафиксирован.

Скрипт 17 создаёт **роли**, но не SQL-логины и пользователей для сервисов.
Создайте два разных логина с уникальными паролями и пользователей с именами,
отличными от имён ролей, например через защищённый SQL-клиент:

```sql
USE master;
CREATE LOGIN [coursework_api_login] WITH PASSWORD = '<unique-api-secret>', CHECK_POLICY = ON;
CREATE LOGIN [coursework_worker_login] WITH PASSWORD = '<unique-worker-secret>', CHECK_POLICY = ON;
GO
USE SocialNetworkDB;
CREATE USER [coursework_api_user] FOR LOGIN [coursework_api_login];
CREATE USER [coursework_worker_user] FOR LOGIN [coursework_worker_login];
ALTER ROLE [coursework_api] ADD MEMBER [coursework_api_user];
ALTER ROLE [coursework_worker] ADD MEMBER [coursework_worker_user];
GO
```

Это шаблон: **не запускайте угловые скобки как пароль и не сохраняйте файл с
подставленными секретами в Git**. Backend использует только логин API,
обработчик — только worker. Обновите их секреты в защищённых переменных среды
хостинга; в `SQLSERVER_DSN` и ODBC-строке укажите порт `3342`, `Encrypt=true`
и `TrustServerCertificate=false`. Пароль с особыми символами в Go URL нужно
URL-кодировать.

## 6. После подключения

- Проверьте `GET /readyz` с реально размещённого backend. `GET /healthz`
  проверяет лишь процесс и не доказывает доступ к БД.
- Проверьте публикацию, обработку очереди worker, индексацию PDF/DOCX,
  RAG-ответ с доступной цитатой и отказ в чтении закрытого сообщества.
- Обновите `web/public/config.js` на проверенный HTTPS-адрес API и лишь затем
  установите `backendReady: true`; повторно опубликуйте Firebase Hosting.
- Следите за оставшимися vCore-часами и датой окончания 12 месяцев. При
  остановленном MI API должен показывать недоступность базы, а не обещать
  круглосуточную работу. Не выполняйте платное обновление тарифа без решения
  о расходах.
