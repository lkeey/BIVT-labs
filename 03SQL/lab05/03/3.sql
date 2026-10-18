-- Отфильтруйте группы продаж товаров так, чтобы включить только те из них, общий объем
-- продаж которых более $20000
-- Измените предыдущий запрос, чтобы он включал только те группы товаров, общая стоимость продаж
-- которых превышает 20 000 долларов.

SELECT
    COUNT(*), product_model.Name AS 'Name'
    ,SUM(order_detail.LineTotal) AS 'TotalRevenue'
FROM SalesLT.Product AS product_model
JOIN SalesLT.SalesOrderDetail AS order_detail
    ON order_detail.ProductID = product_model.ProductID
GROUP BY order_detail.ProductID, product_model.Name
HAVING SUM(order_detail.LineTotal) > 20000
ORDER BY TotalRevenue DESC
