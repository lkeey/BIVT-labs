-- Отфильтруйте список продаж товаров, включив в него только те товары, стоимость
-- которых превышает $1000
-- Измените предыдущий запрос так, чтобы он включал только итоговые сведения по товарам, цена на
-- которые превышает 1000 долларов США

SELECT
    product_model.Name AS 'Name'
    ,product_model.ListPrice AS 'Price per model'
    ,SUM(order_detail.LineTotal) AS 'TotalRevenue'
FROM SalesLT.Product AS product_model
JOIN SalesLT.SalesOrderDetail AS order_detail
    ON order_detail.ProductID = product_model.ProductID
WHERE product_model.ListPrice > 1000
GROUP BY order_detail.ProductID, product_model.Name, product_model.ListPrice
ORDER BY TotalRevenue DESC
