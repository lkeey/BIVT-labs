WITH CustomerOrders AS (
    SELECT 
        customer.CustomerID,
        customer.FirstName, 
        customer.LastName, 
        customer.CompanyName,
        ord.TotalDue
    FROM SalesLT.Customer
    JOIN SalesLT.SalesOrderHeader AS ord
        ON ord.[CustomerID] = customer.[CustomerID]
)

SELECT
    CONCAT(
        customer.CompanyName, N' (', customer.FirstName, N' ', customer.LastName, N')'
    ) AS CompanyContact,
    SUM(customer.TotalDue) AS Revenue
FROM CustomerOrders AS customer
GROUP BY customer.CompanyName,
         customer.FirstName,
         customer.LastName
ORDER BY CompanyContact;
