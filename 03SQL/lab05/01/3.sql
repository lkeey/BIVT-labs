SELECT 
    product.ProductCategoryID,
    LEFT(category_db.Name, 2) AS "SHORT NAME"
FROM SalesLT.Product AS product
JOIN SalesLT.ProductCategory AS category_db
    ON product.ProductCategoryID = category_db.ProductCategoryID
