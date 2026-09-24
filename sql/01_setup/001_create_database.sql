/*
Purpose:
    Create the NovaPayAnalytics database used by the
    NovaPay Remittance Analytics Platform.

Important behaviour:
    The database is created only when it does not already exist.
    Running this script repeatedly will not delete or recreate the database.
*/

USE [master];
GO

IF DB_ID(N'NovaPayAnalytics') IS NULL
BEGIN
    PRINT N'Creating the NovaPayAnalytics database.';

    EXEC (N'CREATE DATABASE [NovaPayAnalytics];');
END
ELSE
BEGIN
    PRINT N'The NovaPayAnalytics database already exists. No database was created.';
END;
GO

ALTER DATABASE [NovaPayAnalytics]
SET RECOVERY SIMPLE;
GO

USE [NovaPayAnalytics];
GO

SELECT
    DB_NAME() AS current_database,
    SUSER_SNAME() AS connected_login,
    SYSDATETIMEOFFSET() AS verification_datetime;
GO