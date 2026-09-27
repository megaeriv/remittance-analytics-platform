/*
Purpose:
    Create the database schemas used by the
    NovaPay Remittance Analytics Platform.

Schemas:
    ref   - Controlled reference values.
    src   - Synthetic operational source data.
    audit - Pipeline execution and data-quality evidence.
    stg   - Cleaned and transformed working data.
    mart  - Reporting-ready analytical data.
*/

USE [NovaPayAnalytics];
GO

SET NOCOUNT ON;
GO

IF SCHEMA_ID(N'ref') IS NULL
BEGIN
    EXEC (N'CREATE SCHEMA [ref] AUTHORIZATION [dbo];');
    PRINT N'Created schema: ref';
END
ELSE
BEGIN
    PRINT N'Schema already exists: ref';
END;
GO

IF SCHEMA_ID(N'src') IS NULL
BEGIN
    EXEC (N'CREATE SCHEMA [src] AUTHORIZATION [dbo];');
    PRINT N'Created schema: src';
END
ELSE
BEGIN
    PRINT N'Schema already exists: src';
END;
GO

IF SCHEMA_ID(N'audit') IS NULL
BEGIN
    EXEC (N'CREATE SCHEMA [audit] AUTHORIZATION [dbo];');
    PRINT N'Created schema: audit';
END
ELSE
BEGIN
    PRINT N'Schema already exists: audit';
END;
GO

IF SCHEMA_ID(N'stg') IS NULL
BEGIN
    EXEC (N'CREATE SCHEMA [stg] AUTHORIZATION [dbo];');
    PRINT N'Created schema: stg';
END
ELSE
BEGIN
    PRINT N'Schema already exists: stg';
END;
GO

IF SCHEMA_ID(N'mart') IS NULL
BEGIN
    EXEC (N'CREATE SCHEMA [mart] AUTHORIZATION [dbo];');
    PRINT N'Created schema: mart';
END
ELSE
BEGIN
    PRINT N'Schema already exists: mart';
END;
GO

SELECT
    name AS schema_name,
    USER_NAME(principal_id) AS schema_owner
FROM sys.schemas
WHERE name IN (N'ref', N'src', N'audit', N'stg', N'mart')
ORDER BY name;
GO