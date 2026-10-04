USE AdventureWorksLT2019;

SELECT 
    c.CompanyName, 
    c.FirstName, 
    c.LastName, 
    ord.SalesOrderID, 
    ord.TotalDue
FROM SalesLT.Customer as c
LEFT JOIN SalesLT.SalesOrderHeader as ord
    ON c.CustomerID = ord.CustomerID
ORDER BY ord.SalesOrderID DESC;