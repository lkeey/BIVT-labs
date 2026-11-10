-- SELECT
--     Name,
--     CASE
--         WHEN Price = 0 THEN N'Бесплатно'
--         WHEN Price < 100 THEN N'Недорого'
--         ELSE N'Дорого'
--     END AS PriceLabel
-- FROM Products;

-- 11

SELECT 
    a.CountryRegion, 
    a.StateProvince, 
    SUM(soh.TotalDue) AS Revenue,
    CASE GROUPING_ID(a.CountryRegion, a.StateProvince)
        WHEN 0 THEN a.StateProvince + N' Subtotal'
        WHEN 1 THEN a.CountryRegion + N' Subtotal'
        WHEN 3 THEN N'Total'
    END AS [Level]
FROM SalesLT.Address AS a
INNER JOIN SalesLT.CustomerAddress AS ca 
    ON a.AddressID = ca.AddressID
INNER JOIN SalesLT.Customer AS c 
    ON ca.CustomerID = c.CustomerID
INNER JOIN SalesLT.SalesOrderHeader as soh 
    ON c.CustomerID = soh.CustomerID
GROUP BY ROLLUP(a.CountryRegion, a.StateProvince)
ORDER BY a.CountryRegion, a.StateProvince;