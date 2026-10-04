USE AdventureWorksLT2019;

SELECT 
    c.CompanyName, 
    ord.SalesOrderID,
    ord.TotalDue, 
    a.AddressLine1, 
    a.AddressLine2, 
    a.City, 
    a.StateProvince, 
    a.PostalCode, 
    a.CountryRegion
FROM SalesLT.Customer AS c
JOIN SalesLT.SalesOrderHeader AS ord 
    ON c.CustomerID=ord.CustomerID
JOIN SalesLT.CustomerAddress AS ca 
    ON c.CustomerID = ca.CustomerID
JOIN SalesLT.Address AS a
    ON ca.AddressID = a.AddressID
WHERE ca.AddressType = 'Main Office';