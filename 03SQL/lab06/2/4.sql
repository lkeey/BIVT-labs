
EXECUTE sp_rename 'lab6.Customer.Phone', 'Mobile', 'COLUMN';

ALTER TABLE lab6.Customer
DROP COLUMN Mobile;