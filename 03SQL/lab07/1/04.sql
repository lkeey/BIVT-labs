-- CREATE FUNCTION lab6.ufnNumbersFrom(@Minimum INT)
-- RETURNS TABLE
-- AS
-- RETURN (
--     SELECT n.Number
--     FROM (VALUES (1), (2), (3)) AS n(Number)
--     WHERE n.Number >= @Minimum
-- );
-- GO

SELECT
    p.ProductID,
    p.Name AS ProductName,
    c.ParentProductCategoryName AS ParentCategory,
    c.ProductCategoryName AS Category
FROM SalesLT.Product AS p
LEFT JOIN dbo.ufnGetAllCategories() AS c
    ON p.ProductCategoryID = c.ProductCategoryID
ORDER BY
    c.ParentProductCategoryName,
    c.ProductCategoryName,
    p.Name;