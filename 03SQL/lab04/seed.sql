-- Небольшой самостоятельно подготовленный набор для практики.
-- Это не официальный набор данных AdventureWorksLT.

INSERT INTO sales.customer (customerid, firstname, lastname, companyname) VALUES
    (1, 'Ava', 'Stone', 'Alpine Ski House'),
    (2, 'Ben', 'Miller', 'Blue Yonder Airlines'),
    (3, 'Cara', 'Woods', 'Coho Bike'),
    (4, 'Drew', 'Young', 'Fabrikam'),
    (5, 'Eli', 'Brown', 'Greenline'),
    (6, 'Faye', 'White', 'Mountain Works'),
    (7, 'Gus', 'Reed', 'Northwind Sports');

INSERT INTO sales.address
    (addressid, addressline1, city, stateprovince, countryregion, postalcode)
VALUES
    (1, '10 Pine Street', 'Seattle', 'Washington', 'United States', '98101'),
    (2, '20 Lake Avenue', 'Spokane', 'Washington', 'United States', '99201'),
    (3, '30 Market Road', 'Boston', 'Massachusetts', 'United States', '02108'),
    (4, '40 Harbor Way', 'Boston', 'Massachusetts', 'United States', '02109'),
    (5, '5 Rue de Lyon', 'Paris', 'Ile-de-France', 'France', '75001'),
    (6, '8 Sakura Lane', 'Tokyo', 'Tokyo', 'Japan', '100-0001'),
    (7, '70 Cedar Road', 'Seattle', 'Washington', 'United States', '98102'),
    (8, '80 Coast Highway', 'Vancouver', 'British Columbia', 'Canada', 'V5K 0A1'),
    (9, '90 Palm Street', 'Miami', 'Florida', 'United States', '33101'),
    (10, '100 Mesa Drive', 'San Diego', 'California', 'United States', '92101'),
    (11, '110 Desert Road', 'Las Vegas', 'Nevada', 'United States', '89101');

INSERT INTO sales.customeraddress (customerid, addressid, addresstype) VALUES
    (1, 1, 'Main Office'), (1, 2, 'Shipping'),
    (2, 3, 'Main Office'), (2, 4, 'Shipping'),
    (3, 5, 'Main Office'),
    (4, 6, 'Shipping'),
    (5, 7, 'Main Office'), (5, 8, 'Shipping'),
    (6, 9, 'Main Office'),
    (7, 10, 'Main Office'), (7, 11, 'Shipping');

INSERT INTO sales.employee (employeeid, firstname, lastname, city, countryregion) VALUES
    (1, 'Ira', 'North', 'Seattle', 'United States'),
    (2, 'Jules', 'West', 'Miami', 'United States'),
    (3, 'Kai', 'East', 'Denver', 'United States'),
    (4, 'Lena', 'South', 'Paris', 'France'),
    (5, 'Mika', 'Lake', 'Seattle', 'United States');

INSERT INTO production.productcategory (productcategoryid, name) VALUES
    (1, 'Bikes'),
    (2, 'Components'),
    (3, 'Clothing');

INSERT INTO production.productmodel (productmodelid, name) VALUES
    (1, 'Road Model'),
    (2, 'Trail Model'),
    (3, 'Everyday Model');

INSERT INTO production.product
    (productid, name, productnumber, color, listprice, sellstartdate, productcategoryid, productmodelid)
VALUES
    (1, 'Trail Bike', 'BK-001', 'Red', 1200, DATE '2026-01-01', 2, 2),
    (2, 'Brake Assembly', 'CP-001', 'Black', 1500, DATE '2026-01-01', 2, 1),
    (3, 'Water Bottle', 'AC-001', 'Blue', 25, DATE '2026-01-01', 1, 3),
    (4, 'Helmet', 'CL-001', NULL, 75, DATE '2026-01-01', 3, 3),
    (5, 'Sticker Set', 'AC-002', NULL, 8, DATE '2026-01-01', 3, 3),
    (6, 'Brake Assembly', 'CP-002', 'Red', 30, DATE '2026-01-01', 2, 1),
    (7, 'Pedal Set', 'CP-003', NULL, 150, DATE '2026-01-01', 2, 2),
    (8, 'Blue Helmet', 'CL-002', 'Blue', 80, DATE '2026-01-01', 3, 3);

-- Align identity sequences with the explicit IDs above so later inserts work.
SELECT setval(pg_get_serial_sequence('sales.customer', 'customerid'), 7);
SELECT setval(pg_get_serial_sequence('sales.address', 'addressid'), 11);
SELECT setval(pg_get_serial_sequence('sales.employee', 'employeeid'), 5);
SELECT setval(pg_get_serial_sequence('production.productcategory', 'productcategoryid'), 3);
SELECT setval(pg_get_serial_sequence('production.productmodel', 'productmodelid'), 3);
SELECT setval(pg_get_serial_sequence('production.product', 'productid'), 8);
