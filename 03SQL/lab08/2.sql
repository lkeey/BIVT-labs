-- SELECT 
--     SalesLT.CompanyName, 
--     Bikes, 
--     Accessories, 
--     Clothing
-- FROM
--     (SELECT OrderID, Category, Revenue FROM Sales.SalesDetails) AS sales
--     PIVOT (SUM(Revenue) FOR Category IN([Bikes], [Accessories], [Clothing])) AS pvt

-- SELECT
--     customer.CompanyName AS Company,
--     product_category.Name AS ProductCategory,
--     parent_category.Name AS ParentCategory,
--     SUM(order_detail.LineTotal) AS LineTotal
-- FROM SalesLT.Customer AS customer
-- INNER JOIN SalesLT.SalesOrderHeader AS order_header
--     ON order_header.CustomerID = customer.CustomerID
-- INNER JOIN SalesLT.SalesOrderDetail AS order_detail
--     ON order_header.SalesOrderID = order_detail.SalesOrderID
-- INNER JOIN SalesLT.Product AS product
--     ON order_detail.ProductID = product.ProductID
-- INNER JOIN SalesLT.ProductCategory AS product_category
--     ON product_category.ProductCategoryID = product.ProductCategoryID
-- INNER JOIN SalesLT.ProductCategory AS parent_category
--     ON product_category.ParentProductCategoryID = parent_category.ProductCategoryID
-- GROUP BY customer.CompanyName, product_category.Name, parent_category.Name

SELECT
    pvt.Company AS CompanyName,
    pvt.Bikes,
    pvt.Accessories,
    pvt.Clothing,
    pvt.Components
FROM (
    SELECT
        customer.CompanyName AS Company,
        parent_category.Name AS ParentCategory,
        SUM(order_detail.LineTotal) AS LineTotal
    FROM SalesLT.Customer AS customer
    INNER JOIN SalesLT.SalesOrderHeader AS order_header
        ON order_header.CustomerID = customer.CustomerID
    INNER JOIN SalesLT.SalesOrderDetail AS order_detail
        ON order_header.SalesOrderID = order_detail.SalesOrderID
    INNER JOIN SalesLT.Product AS product
        ON order_detail.ProductID = product.ProductID
    INNER JOIN SalesLT.ProductCategory AS product_category
        ON product_category.ProductCategoryID = product.ProductCategoryID
    INNER JOIN SalesLT.ProductCategory AS parent_category
        ON product_category.ParentProductCategoryID = parent_category.ProductCategoryID
    GROUP BY customer.CompanyName, parent_category.Name
) AS all_data
PIVOT (SUM(LineTotal) FOR ParentCategory IN ([Bikes], [Accessories], [Clothing], [Components])) AS pvt
ORDER BY CompanyName
