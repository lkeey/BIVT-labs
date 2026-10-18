-- PARTITION BY считает значения отдельно внутри каждой группы,
-- но сохраняет каждую исходную строку результата.
-- Здесь каждая строка — отдельная позиция заказа.

SELECT
    product.Name AS ProductName,
    detail.ProductID,
    detail.SalesOrderID,
    detail.SalesOrderDetailID,
    SUM(detail.LineTotal) AS TotalRevenueForProduct,
    ROW_NUMBER() OVER (
        ORDER BY detail.LineTotal DESC, detail.SalesOrderDetailID
    ) AS RowNumberWithinProduct
FROM SalesLT.SalesOrderDetail AS detail
JOIN SalesLT.Product AS product
    ON product.ProductID = detail.ProductID
GROUP BY
    detail.ProductID,
    detail.LineTotal,
    product.Name,
    detail.SalesOrderID,
    detail.SalesOrderDetailID
ORDER BY
    detail.ProductID,
    detail.LineTotal


-- Как читать результат:
-- * LineTotal — сумма конкретной позиции заказа.
-- * TotalRevenueForProduct — сумма LineTotal по этому товару;
--   она повторяется на каждой строке товара.
-- * ROW_NUMBER начинается заново с 1 для каждого ProductID.
-- * В отличие от GROUP BY, PARTITION BY не схлопывает строки.
