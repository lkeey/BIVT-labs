-- Товары с прейскурантной ценой выше средней цены продажи.
SELECT p.ProductID, p.Name, p.ListPrice
FROM SalesLT.Product AS p
WHERE p.ListPrice > (
    SELECT AVG(d.UnitPrice)
    FROM SalesLT.SalesOrderDetail AS d
)
ORDER BY p.ProductID;
