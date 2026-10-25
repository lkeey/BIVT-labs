USE AdventureWorksLT2019;
GO

CREATE TABLE lab6.Customer
    (
        CustomerID INT NOT NULL PRIMARY KEY,
        Name NVARCHAR(100) NOT NULL,
        City NVARCHAR(50) NOT NULL,
        Email NVARCHAR(100) NULL,

        CreatedAt DATETIME2 NOT NULL
                CONSTRAINT DF_Customer_CreatedAt DEFAULT (SYSDATETIME()),

        CONSTRAINT UQ_Customer_Email UNIQUE (Email)
    )
GO

CREATE TABLE lab6.Product52
    (
        ProductID INT NOT NULL PRIMARY KEY
        -- ProductID INT NOT NULL CONSTRAINT PK_Product PRIMARY KEY
        ,Name NVARCHAR(100) NOT NULL 
        ,Price DECIMAL(10, 2) NOT NULL CHECK (Price >= 0)

        -- ,CONSTRAINT PK_ProductID  (ProductID)
        -- ,CONSTRAINT CK_Product_Price 
    )
GO
