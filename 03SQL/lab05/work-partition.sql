-- PARTITION BY считает значения отдельно внутри каждой группы,
-- но сохраняет каждую исходную строку результата.
-- Здесь каждая строка — отдельная позиция заказа.

SELECT
    product.Name AS ProductName,
    detail.ProductID,
    detail.SalesOrderID,
    detail.SalesOrderDetailID,
    detail.LineTotal,
    SUM(detail.LineTotal) OVER (
        PARTITION BY detail.ProductID
    ) AS TotalRevenueForProduct,
    ROW_NUMBER() OVER (
        PARTITION BY detail.ProductID
        ORDER BY detail.LineTotal DESC, detail.SalesOrderDetailID
    ) AS RowNumberWithinProduct
FROM SalesLT.SalesOrderDetail AS detail
JOIN SalesLT.Product AS product
    ON product.ProductID = detail.ProductID
ORDER BY
    detail.ProductID,
    RowNumberWithinProduct;


-- Как читать результат:
-- * LineTotal — сумма конкретной позиции заказа.
-- * TotalRevenueForProduct — сумма LineTotal по этому товару;
--   она повторяется на каждой строке товара.
-- * ROW_NUMBER начинается заново с 1 для каждого ProductID.
-- * В отличие от GROUP BY, PARTITION BY не схлопывает строки.
