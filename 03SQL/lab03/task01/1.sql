USE AdventureWorksLT2019;

SELECT 
    c.CompanyName, 
    ord.SalesOrderID,
    ord.TotalDue
FROM SalesLT.Customer AS c
JOIN SalesLT.SalesOrderHeader AS ord
    ON c.CustomerID=ord.CustomerID;