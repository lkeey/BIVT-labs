SELECT cust.CustomerID,
 prod.ProductID
FROM SalesLT.Customer AS cust
FULL OUTER JOIN SalesLT.SalesOrderHeader AS soh
ON cust.CustomerID = soh.CustomerID
FULL OUTER JOIN SalesLT.SalesOrderDetail AS sod
ON soh.SalesOrderID = sod.SalesOrderID
FULL OUTER JOIN SalesLT.Product AS prod
ON sod.ProductID = prod.ProductID
WHERE soh.SalesOrderID IS NULL