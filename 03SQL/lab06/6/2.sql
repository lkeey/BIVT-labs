-- Адреса клиентов и имена из табличной функции.
SELECT customer_info.CustomerID,
       customer_info.FirstName,
       customer_info.LastName,
       address_model.AddressLine1,
       address_model.City
FROM SalesLT.CustomerAddress AS customer_address
JOIN SalesLT.Address AS address_model
    ON address_model.AddressID = customer_address.AddressID
CROSS APPLY dbo.ufnGetCustomerInformation(customer_address.CustomerID) AS customer_info
ORDER BY customer_info.CustomerID;
