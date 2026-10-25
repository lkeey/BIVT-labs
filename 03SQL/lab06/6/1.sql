-- Информация о клиенте для каждого заказа.
SELECT order_model.SalesOrderID,
       customer_info.CustomerID,
       customer_info.FirstName,
       customer_info.LastName,
       order_model.TotalDue
FROM SalesLT.SalesOrderHeader AS order_model
CROSS APPLY dbo.ufnGetCustomerInformation(order_model.CustomerID) AS customer_info
ORDER BY order_model.SalesOrderID;
