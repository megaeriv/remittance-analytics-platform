/*
Purpose:
    Create reference tables for NovaPay business processes
    and their permitted status values.

Tables:
    ref.process_types
        One row per status-bearing business process.

    ref.process_statuses
        One row per valid status within a particular process.
*/

USE [NovaPayAnalytics];
GO

SET NOCOUNT ON;
GO

IF OBJECT_ID(N'ref.process_types', N'U') IS NULL
BEGIN
    CREATE TABLE ref.process_types
    (
        process_type_code VARCHAR(50) NOT NULL,
        process_type_name NVARCHAR(100) NOT NULL,
        process_description NVARCHAR(500) NULL,
        is_active BIT NOT NULL
            CONSTRAINT DF_process_types_is_active
            DEFAULT (1),
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_process_types_created_at_utc
            DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_process_types
            PRIMARY KEY (process_type_code)
    );

    PRINT N'Created table: ref.process_types';
END
ELSE
BEGIN
    PRINT N'Table already exists: ref.process_types';
END;
GO

IF OBJECT_ID(N'ref.process_statuses', N'U') IS NULL
BEGIN
    CREATE TABLE ref.process_statuses
    (
        process_type_code VARCHAR(50) NOT NULL,
        status_code VARCHAR(60) NOT NULL,
        status_name NVARCHAR(100) NOT NULL,
        status_description NVARCHAR(500) NULL,
        is_terminal BIT NOT NULL
            CONSTRAINT DF_process_statuses_is_terminal
            DEFAULT (0),
        is_active BIT NOT NULL
            CONSTRAINT DF_process_statuses_is_active
            DEFAULT (1),
        display_order SMALLINT NULL,
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_process_statuses_created_at_utc
            DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_process_statuses
            PRIMARY KEY
            (
                process_type_code,
                status_code
            ),

        CONSTRAINT FK_process_statuses_process_types
            FOREIGN KEY (process_type_code)
            REFERENCES ref.process_types (process_type_code),

        CONSTRAINT CK_process_statuses_display_order
            CHECK
            (
                display_order IS NULL
                OR display_order > 0
            )
    );

    PRINT N'Created table: ref.process_statuses';
END
ELSE
BEGIN
    PRINT N'Table already exists: ref.process_statuses';
END;
GO

SELECT
    SCHEMA_NAME(t.schema_id) AS schema_name,
    t.name AS table_name,
    COUNT(c.column_id) AS column_count
FROM sys.tables AS t
INNER JOIN sys.columns AS c
    ON t.object_id = c.object_id
WHERE
    SCHEMA_NAME(t.schema_id) = N'ref'
    AND t.name IN
    (
        N'process_types',
        N'process_statuses'
    )
GROUP BY
    t.schema_id,
    t.name
ORDER BY
    t.name;
GO