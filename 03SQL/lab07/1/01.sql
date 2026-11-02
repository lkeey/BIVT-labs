SELECT 
    product.ProductID,
    product.Name AS 'ProductName', 
    vProduct.Name AS 'ProductModel', 
    vProduct.Summary AS 'Summary'
FROM SalesLT.Product AS product
JOIN SalesLT.vProductModelCatalogDescription AS vProduct
    ON vProduct.ProductModelID = product.ProductModelID
ORDER BY product.ProductID

-- SELECT TOP (0) * FROM SalesLT.Product;
-- SELECT TOP (0) * FROM SalesLT.vProductModelCatalogDescription;