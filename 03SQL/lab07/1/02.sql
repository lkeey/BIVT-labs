-- DECLARE @Codes TABLE (Code NVARCHAR(10));

-- INSERT INTO @Codes (Code)
-- SELECT DISTINCT x.Code
-- FROM (VALUES (N'A'), (N'A'), (N'B')) AS x(Code);

-- SELECT x.Code
-- FROM (VALUES (N'A'), (N'B'), (N'C')) AS x(Code)
-- WHERE x.Code IN (SELECT Code FROM @Codes)
-- ORDER BY x.Code;

DECLARE @Colors TABLE (ColorName NVARCHAR(15))

INSERT INTO @Colors 
SELECT DISTINCT SalesLT.Product.Color
FROM SalesLT.Product

-- идентификатор товара,
-- название товара (столбец ProductName) и цвет (столбец Color) из таблицы SalesLT.Product

SELECT 
    product.ProductID,
    product.Name AS 'ProductName',
    colors.ColorName AS 'Color' 
FROM SalesLT.Product AS product
JOIN @Colors AS colors
    ON product.Color = colors.ColorName
ORDER BY colors.ColorName