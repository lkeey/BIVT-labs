USE AdventureWorksLT2019;
GO

DECLARE @OrderDate date = CAST(GETDATE() AS date);
DECLARE @DueDate date = DATEADD(day, 7, @OrderDate);
DECLARE @CustomerID int = 1;
DECLARE @SalesOrderID int;

INSERT INTO SalesLT.SalesOrderHeader
    (OrderDate, DueDate, CustomerID, ShipMethod)
VALUES
    (@OrderDate, @DueDate, @CustomerID, N'CARGO TRANSPORT 5');

SET @SalesOrderID = CONVERT(int, SCOPE_IDENTITY());

PRINT CONCAT(N'SalesOrderID: ', @SalesOrderID);