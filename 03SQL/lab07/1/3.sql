-- CREATE TABLE #AllowedCodes (Code NVARCHAR(10));

-- INSERT INTO #AllowedCodes (Code)
-- SELECT DISTINCT x.Code
-- FROM (VALUES (N'A'), (N'A'), (N'B')) AS x(Code);

-- SELECT x.Code
-- FROM (VALUES (N'A'), (N'B'), (N'C')) AS x(Code)
-- WHERE x.Code IN (SELECT Code FROM #AllowedCodes)
-- ORDER BY x.Code DESC;

-- DROP TABLE #AllowedCodes;

CREATE TABLE #UniqueSizes (Size NVARCHAR(5));

INSERT INTO #UniqueSizes
SELECT DISTINCT SalesLT.Product.[Size]
FROM SalesLT.Product

SELECT 
    product.ProductID,
    product.Name AS 'ProductName',
    sizes.Size AS 'Size' 
FROM SalesLT.Product AS product
JOIN #UniqueSizes AS sizes
    ON product.Size = sizes.Size
ORDER BY sizes.Size DESC

DROP TABLE #UniqueSizes