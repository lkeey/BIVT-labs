USE AdventureWorksLT2019;
GO

-- Тестовые клиенты и изменения существующих ограничений откатываются.
-- В конце CK_Customer_Email остаётся доверенным (или добавляется, если его
-- ещё не было). Старое email_check из 3_1.sql сохраняет исходное состояние.

-- 1. Добавляем клиента с email без @ и пробуем создать CHECK.
-- Если CK_Customer_Email или старое email_check уже существуют, временно
-- убираем их внутри транзакции, иначе неверная вставка сразу будет отклонена.
DECLARE @ExpectedError BIT = 0;
BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE parent_object_id = OBJECT_ID(N'lab6.Customer')
                 AND name = N'CK_Customer_Email')
        ALTER TABLE lab6.Customer DROP CONSTRAINT CK_Customer_Email;

    IF EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE parent_object_id = OBJECT_ID(N'lab6.Customer')
                 AND name = N'email_check')
        ALTER TABLE lab6.Customer DROP CONSTRAINT email_check;

    DECLARE @BadCustomerID INT =
        (SELECT ISNULL(MAX(CustomerID), 0) + 1 FROM lab6.Customer);

    INSERT INTO lab6.Customer (CustomerID, Name, City, Email)
    VALUES (@BadCustomerID, N'Тестовый клиент', N'Москва',
            CONCAT(N'lab6-invalid-', @BadCustomerID));

    BEGIN TRY
        ALTER TABLE lab6.Customer WITH CHECK
            ADD CONSTRAINT CK_Customer_Email CHECK (Email LIKE N'%@%');
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() <> 547 THROW;
        SET @ExpectedError = 1;
        SELECT ERROR_NUMBER() AS ErrorNumber,
               ERROR_MESSAGE() AS ErrorMessage;
    END CATCH;

    -- Ошибка 547 означает: добавляемый CHECK противоречит существующей строке.
    -- После ошибки ALTER TABLE транзакция непригодна для дальнейших изменений.
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF @ExpectedError = 0
        THROW 50001, N'Ожидаемая ошибка CHECK не возникла.', 1;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- 2. В новой транзакции снова добавляем неверную строку, исправляем её
-- и успешно создаём CHECK с проверкой всех существующих данных.
BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE parent_object_id = OBJECT_ID(N'lab6.Customer')
                 AND name = N'CK_Customer_Email')
        ALTER TABLE lab6.Customer DROP CONSTRAINT CK_Customer_Email;

    IF EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE parent_object_id = OBJECT_ID(N'lab6.Customer')
                 AND name = N'email_check')
        ALTER TABLE lab6.Customer DROP CONSTRAINT email_check;

    DECLARE @FixedCustomerID INT =
        (SELECT ISNULL(MAX(CustomerID), 0) + 1 FROM lab6.Customer);

    INSERT INTO lab6.Customer (CustomerID, Name, City, Email)
    VALUES (@FixedCustomerID, N'Тестовый клиент', N'Москва',
            CONCAT(N'lab6-invalid-', @FixedCustomerID));

    UPDATE lab6.Customer
    SET Email = CONCAT(N'lab6-valid-', @FixedCustomerID, N'@example.org')
    WHERE CustomerID = @FixedCustomerID;

    ALTER TABLE lab6.Customer WITH CHECK
        ADD CONSTRAINT CK_Customer_Email CHECK (Email LIKE N'%@%');

    SELECT c.CustomerID, c.Email, ck.is_not_trusted
    FROM lab6.Customer AS c
    CROSS JOIN sys.check_constraints AS ck
    WHERE c.CustomerID = @FixedCustomerID
      AND ck.parent_object_id = OBJECT_ID(N'lab6.Customer')
      AND ck.name = N'CK_Customer_Email';
    -- is_not_trusted = 0: существующие данные проверены.

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- Если ограничение ещё не существовало до демонстрации, добавляем его
-- постоянно. Уже существующее недоверенное CK_Customer_Email перепроверяем.
IF EXISTS (SELECT 1 FROM lab6.Customer
           WHERE Email IS NOT NULL AND Email NOT LIKE N'%@%')
    THROW 50002, N'Сначала исправьте существующие email без @.', 1;

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE parent_object_id = OBJECT_ID(N'lab6.Customer')
                 AND name = N'CK_Customer_Email')
    ALTER TABLE lab6.Customer WITH CHECK
        ADD CONSTRAINT CK_Customer_Email CHECK (Email LIKE N'%@%');
ELSE IF EXISTS (SELECT 1 FROM sys.check_constraints
                WHERE parent_object_id = OBJECT_ID(N'lab6.Customer')
                  AND name = N'CK_Customer_Email'
                  AND is_not_trusted = 1)
    ALTER TABLE lab6.Customer WITH CHECK CHECK CONSTRAINT CK_Customer_Email;

SELECT name, definition, is_not_trusted
FROM sys.check_constraints
WHERE parent_object_id = OBJECT_ID(N'lab6.Customer')
  AND name = N'CK_Customer_Email';
GO

-- 3. CHECK пропускает NULL: NULL LIKE '%@%' имеет значение UNKNOWN,
-- а CHECK отклоняет только FALSE. Пробную вставку откатываем.
-- UQ_Customer_Email допускает только один NULL в SQL Server, поэтому
-- временно заполняем Email уже существующего клиента без адреса.
BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE lab6.Customer
    SET Email = CONCAT(N'lab6-null-', CONVERT(NVARCHAR(36), NEWID()),
                       N'@example.org')
    WHERE Email IS NULL;

    DECLARE @NullCustomerID INT =
        (SELECT ISNULL(MAX(CustomerID), 0) + 1 FROM lab6.Customer);

    INSERT INTO lab6.Customer (CustomerID, Name, City, Email)
    VALUES (@NullCustomerID, N'Проверка NULL', N'Москва', NULL);

    SELECT CustomerID, Email
    FROM lab6.Customer
    WHERE CustomerID = @NullCustomerID;

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- 4. WITH NOCHECK не проверяет уже записанный неверный email: CHECK
-- создаётся недоверенным (is_not_trusted = 1). Новые/изменённые строки
-- проверяются, но старые ошибки остаются; оптимизатор не полагается на
-- недоверенное ограничение. Поэтому WITH NOCHECK здесь не рекомендуется.
BEGIN TRY
    BEGIN TRANSACTION;

    ALTER TABLE lab6.Customer DROP CONSTRAINT CK_Customer_Email;

    IF EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE parent_object_id = OBJECT_ID(N'lab6.Customer')
                 AND name = N'email_check')
        ALTER TABLE lab6.Customer DROP CONSTRAINT email_check;

    DECLARE @NocheckCustomerID INT =
        (SELECT ISNULL(MAX(CustomerID), 0) + 1 FROM lab6.Customer);

    INSERT INTO lab6.Customer (CustomerID, Name, City, Email)
    VALUES (@NocheckCustomerID, N'Проверка NOCHECK', N'Москва',
            CONCAT(N'lab6-invalid-', @NocheckCustomerID));

    ALTER TABLE lab6.Customer WITH NOCHECK
        ADD CONSTRAINT CK_Customer_Email CHECK (Email LIKE N'%@%');

    SELECT c.CustomerID, c.Email, ck.is_not_trusted
    FROM lab6.Customer AS c
    CROSS JOIN sys.check_constraints AS ck
    WHERE c.CustomerID = @NocheckCustomerID
      AND ck.parent_object_id = OBJECT_ID(N'lab6.Customer')
      AND ck.name = N'CK_Customer_Email';

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- Итог: действующее CK_Customer_Email осталось доверенным.
SELECT name, is_not_trusted
FROM sys.check_constraints
WHERE parent_object_id = OBJECT_ID(N'lab6.Customer')
  AND name = N'CK_Customer_Email';
GO
