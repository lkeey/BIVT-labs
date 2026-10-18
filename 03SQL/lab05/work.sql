SELECT
    customer.CustomerID,
    customer.CompanyName,
    order_model.SalesOrderID,
    order_model.TotalDue
FROM SalesLT.Customer AS customer
JOIN SalesLT.SalesOrderHeader AS order_model
    ON order_model.CustomerID = customer.CustomerID
WHERE customer.CustomerID = 29736;
