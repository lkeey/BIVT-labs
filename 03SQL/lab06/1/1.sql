USE AdventureWorksLT2019;
GO

CREATE SCHEMA lab6
    CREATE TABLE Lab6_DDL
    (
        name VARCHAR(20),
        id INT,
        cost FLOAT
    )

    -- GRANT SELECT ON SCHEMA::Sprockets TO Mandar
    -- DENY SELECT ON SCHEMA::Sprockets TO Prasanna;
GO