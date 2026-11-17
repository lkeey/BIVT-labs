USE AdventureWorksLT2019;
GO

DECLARE @SalesOrderID int = 71949;
DECLARE @ProductID int = 760;
DECLARE @Quantity smallint = 1;
DECLARE @UnitPrice money = 782.99;

IF EXISTS (
    SELECT *
    FROM SalesLT.SalesOrderHeader
    WHERE SalesOrderID = @SalesOrderID
)
BEGIN
    INSERT INTO SalesLT.SalesOrderDetail
        (SalesOrderID, ProductID, OrderQty, UnitPrice)
    VALUES
        (@SalesOrderID, @ProductID, @Quantity, @UnitPrice);
END
ELSE
BEGIN
    PRINT N'Заказ не существует';
END;