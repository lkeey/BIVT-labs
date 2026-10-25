ALTER TABLE lab6.Customer WITH NOCHECK
    ADD CONSTRAINT email_check CHECK (Email LIKE N'%@%');
GO
