USE AdventureWorksLT2019;
GO

-- Задача 1.1. Получить сведения о клиентах
SELECT *
FROM SalesLT.Customer;

-- Задача 1.2. Получить данные по имени клиента
SELECT
    Title,
    FirstName,
    MiddleName,
    LastName,
    Suffix
FROM SalesLT.Customer;

-- Задача 1.3. Получить имена клиентов и номера телефонов
SELECT
    SalesPerson,
    ISNULL(Title + ' ', '') + LastName AS CustomerName,
    Phone
FROM SalesLT.Customer;

-- Задача 2.1. Получить список компаний-клиентов
SELECT
    CAST(CustomerID AS varchar(10)) + ': ' + CompanyName AS CustomerCompany
FROM SalesLT.Customer;

-- Задача 2.2. Получить список изменений заказа клиента
SELECT
    SalesOrderNumber + ' (' + CAST(RevisionNumber AS VARCHAR(10)) + ')' AS OrderRevision,
    CONVERT(char(10), OrderDate, 102) AS OrderDate
FROM SalesLT.SalesOrderHeader;

-- Задача 3.1. Получить имена контактов с отчествами, если они известны
SELECT
    FirstName + ' ' + ISNULL(MiddleName + ' ', '') + LastName AS CustomerName
FROM SalesLT.Customer;

-- Задача 3.2. Получить первичные контактные данные
BEGIN TRANSACTION;

UPDATE SalesLT.Customer
SET EmailAddress = NULL
WHERE CustomerID % 7 = 1;

SELECT
    CustomerID,
    ISNULL(EmailAddress, Phone) AS PrimaryContact
FROM SalesLT.Customer;

ROLLBACK TRANSACTION;

-- Задача 3.3. Получить статус доставки
BEGIN TRANSACTION;

UPDATE SalesLT.SalesOrderHeader
SET ShipDate = NULL
WHERE SalesOrderID > 71899;

SELECT
    SalesOrderID,
    OrderDate,
    CASE
        WHEN ShipDate IS NOT NULL THEN 'Shipped'
        ELSE 'Awaiting Shipment'
    END AS ShippingStatus
FROM SalesLT.SalesOrderHeader;

ROLLBACK TRANSACTION;
