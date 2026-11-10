SELECT a.CountryRegion, a.StateProvince, SUM(soh.TotalDue) AS Revenue
FROM SalesLT.Address AS a
INNER JOIN SalesLT.CustomerAddress AS ca 
    ON a.AddressID = ca.AddressID
INNER JOIN SalesLT.Customer AS c 
    ON ca.CustomerID = c.CustomerID
INNER JOIN SalesLT.SalesOrderHeader as soh 
    ON c.CustomerID = soh.CustomerID
GROUP BY ROLLUP(a.CountryRegion, a.StateProvince)
ORDER BY a.CountryRegion, a.StateProvince;