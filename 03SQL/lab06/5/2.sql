-- Товары с ListPrice >= 100, проданные хотя бы раз дешевле 100.
SELECT p.ProductID, p.Name, p.ListPrice
FROM SalesLT.Product AS p
WHERE p.ListPrice >= 100
  AND EXISTS (
      SELECT 1
      FROM SalesLT.SalesOrderDetail AS d
      WHERE d.ProductID = p.ProductID
        AND d.UnitPrice < 100
  )
ORDER BY p.ProductID;
