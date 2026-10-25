-- 1. Получите общий объем продаж по товару
-- Напишите запрос для извлечения списка наименований товаров (столбец Name) и итоговой суммы
-- (столбец TotalRevenue), рассчитанной как сумма LineTotal из таблицы SalesLT.SalesOrderDetail. Результаты
-- отсортируйте по убыванию общей выручки.

SELECT
    product_model.Name AS 'Name'
    ,SUM(order_detail.LineTotal) AS 'TotalRevenue'
FROM SalesLT.Product AS product_model
JOIN SalesLT.SalesOrderDetail AS order_detail
    ON order_detail.ProductID = product_model.ProductID
GROUP BY order_detail.ProductID, product_model.Name
ORDER BY TotalRevenue DESC
