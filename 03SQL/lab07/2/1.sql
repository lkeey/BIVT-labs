-- SELECT x.Color, SUM(x.Price) AS TotalPrice
-- FROM (
--     SELECT Color, ListPrice AS Price
--     FROM SalesLT.Product
-- ) AS x
-- GROUP BY x.Color
-- ORDER BY x.Color;

SELECT 
    CONCAT(
        customer.CompanyName, N' (', customer.FirstName, N' ', customer.LastName, N')'
    ) AS CompanyContact,
    SUM(customer.TotalDue) AS Revenue
FROM (
    SELECT 
        customer.CustomerID,
        customer.FirstName, 
        customer.LastName, 
        customer.CompanyName,
        ord.TotalDue
    FROM SalesLT.Customer
    JOIN SalesLT.SalesOrderHeader AS ord
        ON ord.[CustomerID] = customer.[CustomerID]
) AS customer
GROUP BY customer.CompanyName,
         customer.FirstName,
         customer.LastName
ORDER BY CompanyContact;
