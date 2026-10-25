USE AdventureWorksLT2019;
GO

CREATE TABLE lab6.Orders
    (
        OrderID INT IDENTITY(1,1) NOT NULL PRIMARY KEY
        , OrderDate DATE NOT NULL
            CONSTRAINT DF_Orders_OrderDate 
            DEFAULT (CAST(SYSDATETIME() AS DATE))
        , CustomerID INT NOT NULL

        , CONSTRAINT FK_CustomerID FOREIGN KEY (CustomerID)
            REFERENCES lab6.Customer(CustomerID)
    )
GO

CREATE TABLE lab6.OrderLine
    (
        OrderID INT NOT NULL
        , ProductID INT NOT NULL
        , Qty INT NOT NULL

        , CONSTRAINT PK_OrderLine PRIMARY KEY (OrderID, ProductID)
        , CONSTRAINT FK_OrderLine_OrderID FOREIGN KEY (OrderID)
            REFERENCES lab6.Orders(OrderID) ON DELETE CASCADE
        , CONSTRAINT FK_OrderLine_ProductID FOREIGN KEY (ProductID)
            REFERENCES lab6.Product(ProductID)
        , CONSTRAINT CK_OrderLine_Qty CHECK (Qty > 0)
    )
GO
