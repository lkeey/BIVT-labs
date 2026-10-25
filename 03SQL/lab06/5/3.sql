-- Средняя цена продажи равна NULL, если товар ещё не продавался.
SELECT p.ProductID, p.Name, p.StandardCost, p.ListPrice,
       (
           SELECT AVG(d.UnitPrice)
           FROM SalesLT.SalesOrderDetail AS d
           WHERE d.ProductID = p.ProductID
       ) AS AvgSellingPrice
FROM SalesLT.Product AS p
ORDER BY p.ProductID;
