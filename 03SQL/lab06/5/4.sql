-- Товары, средняя цена продажи которых ниже себестоимости.
SELECT prices.ProductID, prices.Name, prices.StandardCost,
       prices.ListPrice, prices.AvgSellingPrice
FROM (
    SELECT p.ProductID, p.Name, p.StandardCost, p.ListPrice,
           (
               SELECT AVG(d.UnitPrice)
               FROM SalesLT.SalesOrderDetail AS d
               WHERE d.ProductID = p.ProductID
           ) AS AvgSellingPrice
    FROM SalesLT.Product AS p
) AS prices
WHERE prices.StandardCost > prices.AvgSellingPrice
ORDER BY prices.ProductID;
