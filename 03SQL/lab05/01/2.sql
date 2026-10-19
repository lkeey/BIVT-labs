SELECT 
    DATENAME(MONTH, SellStartDate) AS StartMonth,
    ISNULL(CAST(DATENAME(MONTH, SellEndDate) AS varchar(50)), CAST('empty' AS varchar(50))) AS EndMonth
FROM SalesLT.Product