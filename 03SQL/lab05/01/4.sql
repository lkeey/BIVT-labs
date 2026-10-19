SELECT 
    product.ProductCategoryID,
    LEFT(category_db.Name, 2) AS "SHORT NAME",
    product.Size AS "SIZE"
FROM SalesLT.Product AS product
JOIN SalesLT.ProductCategory AS category_db
    ON product.ProductCategoryID = category_db.ProductCategoryID
WHERE ISNUMERIC(product.Size) = 1 AND 
    -- product.Size LIKE '7%' AND 
    product.Size % 10 = 0;