USE AdventureWorksLT2019;
GO

-- Задача 1.1. Получить список городов
SELECT DISTINCT
    City,
    StateProvince
FROM SalesLT.Address;

-- Задача 1.2. Получить самые тяжёлые товары
SELECT TOP (10) PERCENT
    Name
FROM SalesLT.Product
ORDER BY Weight DESC;

-- Задача 1.3. Получить самые тяжёлые 100 товаров без первых десяти
SELECT
    Name
FROM SalesLT.Product
ORDER BY Weight DESC
OFFSET 10 ROWS
FETCH NEXT 100 ROWS ONLY;

-- Задача 2.1. Получить информацию о товарах модели 1
SELECT
    Name,
    Color,
    Size
FROM SalesLT.Product
WHERE ProductModelID = 1;

-- Задача 2.2. Отфильтровать товары по цвету и размеру
SELECT
    ProductNumber,
    Name
FROM SalesLT.Product
WHERE Color IN ('Black', 'Red', 'White')
  AND Size IN ('S', 'M');

-- Задача 2.3. Отфильтровать товары по началу товарного номера
SELECT
    ProductNumber,
    Name,
    ListPrice
FROM SalesLT.Product
WHERE ProductNumber LIKE 'BK-%';

-- Задача 2.4. Получить определённые товары по товарному номеру
SELECT
    ProductNumber,
    Name,
    ListPrice
FROM SalesLT.Product
WHERE ProductNumber LIKE 'BK-[^R]%-[0-9][0-9]';
