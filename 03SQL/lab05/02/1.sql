-- CompanyName, TotalDue (Revenue),
-- ранг (по уменьшению значений TotalDue) from SalesOrderHeader RankByRevenue

SELECT
    CompanyName,
    customer.CustomerID
    ,order_model.TotalDue AS 'Revenue'
    ,RANK() OVER (ORDER BY order_model.TotalDue DESC) AS 'RankByRevenue'
FROM SalesLT.Customer AS customer
    JOIN SalesLT.SalesOrderHeader AS order_model
        ON order_model.CustomerID = customer.CustomerID
ORDER BY RankByRevenue

SELECT
    customer.CustomerID,
    customer.CompanyName,
    SUM(order_model.TotalDue) AS Revenue,
    RANK() OVER (
        ORDER BY SUM(order_model.TotalDue) DESC
    ) AS RankByRevenue
FROM SalesLT.Customer AS customer
JOIN SalesLT.SalesOrderHeader AS order_model
    ON order_model.CustomerID = customer.CustomerID
GROUP BY
    customer.CustomerID,
    customer.CompanyName
ORDER BY
    SUM(order_model.TotalDue) DESC;
