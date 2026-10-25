USE AdventureWorksLT2019;
GO

-- Запускать один раз после создания пустых таблиц lab6.Customer, Product, Orders и OrderLine.
-- CreatedAt и OrderDate не указываем: их заполняют ограничения DEFAULT.
INSERT INTO lab6.Customer (CustomerID, Name, City, Email)
VALUES
    (1, N'Анна Иванова', N'Москва', N'anna.lab6@example.org'),
    (2, N'Борис Петров', N'Казань', N'boris.lab6@example.org'),
    (3, N'Вера Смирнова', N'Тверь', NULL);

INSERT INTO lab6.Product (ProductID, Name, Price)
VALUES
    (1, N'Книга', 450.00),
    (2, N'Ручка', 80.00),
    (3, N'Блокнот', 150.00);

DECLARE @Order1 INT, @Order2 INT;

INSERT INTO lab6.Orders (CustomerID) VALUES (1);
SET @Order1 = CONVERT(INT, SCOPE_IDENTITY());

INSERT INTO lab6.Orders (CustomerID) VALUES (2);
SET @Order2 = CONVERT(INT, SCOPE_IDENTITY());

INSERT INTO lab6.OrderLine (OrderID, ProductID, Qty)
VALUES
    (@Order1, 1, 2),
    (@Order1, 2, 1),
    (@Order2, 3, 1);

-- Каждую неверную вставку выполняем в транзакции. Если ограничение
-- почему-либо не сработает, ROLLBACK всё равно не сохранит ошибочные данные.
-- ERROR_MESSAGE() выводит точный текст ошибки SQL Server для отчёта.

-- 1. Отрицательная цена: ожидается CK_Product_Price.
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO lab6.Product (ProductID, Name, Price)
    VALUES (4, N'Товар с отрицательной ценой', -10.00);
    ROLLBACK TRANSACTION;
    SELECT N'Отрицательная цена' AS TestName,
           N'Ошибка не возникла: проверьте CK_Product_Price' AS ErrorText;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'Отрицательная цена' AS TestName, ERROR_MESSAGE() AS ErrorText;
END CATCH;

-- 2. Несуществующий товар: ожидается FK_OrderLine_ProductID.
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO lab6.OrderLine (OrderID, ProductID, Qty)
    VALUES (@Order1, 999999, 1);
    ROLLBACK TRANSACTION;
    SELECT N'Несуществующий ProductID' AS TestName,
           N'Ошибка не возникла: проверьте FK_OrderLine_ProductID' AS ErrorText;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'Несуществующий ProductID' AS TestName, ERROR_MESSAGE() AS ErrorText;
END CATCH;

-- 3. Повтор email: ожидается UQ_Customer_Email.
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO lab6.Customer (CustomerID, Name, City, Email)
    VALUES (4, N'Галина Орлова', N'Самара', N'anna.lab6@example.org');
    ROLLBACK TRANSACTION;
    SELECT N'Повтор email' AS TestName,
           N'Ошибка не возникла: проверьте UQ_Customer_Email' AS ErrorText;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'Повтор email' AS TestName, ERROR_MESSAGE() AS ErrorText;
END CATCH;

-- 4. Второй клиент без email: SQL Server допускает только один NULL
-- в столбце с таким ограничением UNIQUE.
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO lab6.Customer (CustomerID, Name, City, Email)
    VALUES (5, N'Дмитрий Соколов', N'Омск', NULL);
    ROLLBACK TRANSACTION;
    SELECT N'Второй NULL в Email' AS TestName,
           N'Ошибка не возникла: проверьте UQ_Customer_Email' AS ErrorText;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT N'Второй NULL в Email' AS TestName, ERROR_MESSAGE() AS ErrorText;
END CATCH;
GO
