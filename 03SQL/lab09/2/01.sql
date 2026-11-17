USE AdventureWorksLT2019;
GO

DECLARE @AveragePrice money;
DECLARE @MaximumPrice money;

SELECT
    @AveragePrice = AVG(p.ListPrice),
    @MaximumPrice = MAX(p.ListPrice)
FROM SalesLT.Product AS p
INNER JOIN SalesLT.vGetAllCategories AS c
    ON c.ProductCategoryID = p.ProductCategoryID
WHERE c.ParentProductCategoryName = N'Bikes';

WHILE @AveragePrice < 2000
BEGIN
    UPDATE p
    SET ListPrice = p.ListPrice * 1.10
    FROM SalesLT.Product AS p
    INNER JOIN SalesLT.vGetAllCategories AS c
        ON c.ProductCategoryID = p.ProductCategoryID
    WHERE c.ParentProductCategoryName = N'Bikes';

    SELECT
        @AveragePrice = AVG(p.ListPrice),
        @MaximumPrice = MAX(p.ListPrice)
    FROM SalesLT.Product AS p
    INNER JOIN SalesLT.vGetAllCategories AS c
        ON c.ProductCategoryID = p.ProductCategoryID
    WHERE c.ParentProductCategoryName = N'Bikes';

    IF @MaximumPrice >= 5000
        BREAK;
END;

PRINT CONCAT(N'Новая средняя цена на велосипед: ', @AveragePrice);
PRINT CONCAT(N'Новая максимальная цена велосипеда: ', @MaximumPrice);
