-- 000 = 0
-- 001 = 1
-- 011 = 3
-- 111 = 7

SELECT 
    a.CountryRegion, 
    a.StateProvince, 
    a.City, 
    SUM(soh.TotalDue) AS Revenue,
    CASE GROUPING_ID(a.CountryRegion, a.StateProvince, a.City)
        WHEN 0 THEN a.City + N' Subtotal'
        WHEN 1 THEN a.StateProvince + N' Subtotal'
        WHEN 3 THEN a.CountryRegion + N' Subtotal'
        WHEN 7 THEN N'Total'
    END AS [Level]
FROM SalesLT.Address AS a
INNER JOIN SalesLT.CustomerAddress AS ca 
    ON a.AddressID = ca.AddressID
INNER JOIN SalesLT.Customer AS c 
    ON ca.CustomerID = c.CustomerID
INNER JOIN SalesLT.SalesOrderHeader as soh 
    ON c.CustomerID = soh.CustomerID
GROUP BY ROLLUP(a.CountryRegion, a.StateProvince, a.City)
ORDER BY a.CountryRegion, a.StateProvince, a.City;