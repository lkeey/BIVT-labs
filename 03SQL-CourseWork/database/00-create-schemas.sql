/* SQL Server 2025. Run with sqlcmd -b in a NEW dedicated database.
   This is intentionally not a migration: never reset or overwrite a legacy DB. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
IF EXISTS (SELECT 1 FROM sys.tables
           WHERE (object_id = OBJECT_ID(N'auth.UserAccount') AND is_node = 1)
              OR schema_id IN (SCHEMA_ID(N'knowledge'), SCHEMA_ID(N'assistant')))
    THROW 51300, N'Legacy coursework schema detected. Use a new database; preserve and migrate old data separately.', 1;
IF SCHEMA_ID(N'auth') IS NULL EXEC(N'CREATE SCHEMA auth AUTHORIZATION dbo;');
IF SCHEMA_ID(N'social') IS NULL EXEC(N'CREATE SCHEMA social AUTHORIZATION dbo;');
IF SCHEMA_ID(N'ops') IS NULL EXEC(N'CREATE SCHEMA ops AUTHORIZATION dbo;');
GO
