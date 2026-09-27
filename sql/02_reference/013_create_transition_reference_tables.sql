/*
Purpose:
    Create reference tables for transition categories and
    permitted movements between NovaPay process statuses.

Design rule:
    A transition is allowed only when a matching row exists
    in ref.allowed_status_transitions.
*/

USE [NovaPayAnalytics];
GO

SET NOCOUNT ON;
GO

IF OBJECT_ID(N'ref.transition_types', N'U') IS NULL
BEGIN
    CREATE TABLE ref.transition_types
    (
        transition_type_code VARCHAR(30) NOT NULL,
        transition_type_name NVARCHAR(100) NOT NULL,
        transition_type_description NVARCHAR(500) NULL,
        is_active BIT NOT NULL
            CONSTRAINT DF_transition_types_is_active
            DEFAULT (1),
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_transition_types_created_at_utc
            DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_transition_types
            PRIMARY KEY (transition_type_code)
    );

    PRINT N'Created table: ref.transition_types';
END
ELSE
BEGIN
    PRINT N'Table already exists: ref.transition_types';
END;
GO

IF OBJECT_ID(N'ref.allowed_status_transitions', N'U') IS NULL
BEGIN
    CREATE TABLE ref.allowed_status_transitions
    (
        transition_id INT IDENTITY(1, 1) NOT NULL,
        process_type_code VARCHAR(50) NOT NULL,
        from_status_code VARCHAR(60) NULL,
        to_status_code VARCHAR(60) NOT NULL,
        transition_type_code VARCHAR(30) NOT NULL,

        requires_reason BIT NOT NULL
            CONSTRAINT DF_allowed_transitions_requires_reason
            DEFAULT (0),

        requires_approval BIT NOT NULL
            CONSTRAINT DF_allowed_transitions_requires_approval
            DEFAULT (0),

        creates_exception BIT NOT NULL
            CONSTRAINT DF_allowed_transitions_creates_exception
            DEFAULT (0),

        is_terminal_transition BIT NOT NULL
            CONSTRAINT DF_allowed_transitions_is_terminal
            DEFAULT (0),

        transition_notes NVARCHAR(500) NULL,

        is_active BIT NOT NULL
            CONSTRAINT DF_allowed_transitions_is_active
            DEFAULT (1),

        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_allowed_transitions_created_at_utc
            DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_allowed_status_transitions
            PRIMARY KEY (transition_id),

        CONSTRAINT UQ_allowed_transitions_process_from_to
            UNIQUE
            (
                process_type_code,
                from_status_code,
                to_status_code
            ),

        CONSTRAINT FK_allowed_transitions_process_type
            FOREIGN KEY (process_type_code)
            REFERENCES ref.process_types (process_type_code),

        CONSTRAINT FK_allowed_transitions_from_status
            FOREIGN KEY
            (
                process_type_code,
                from_status_code
            )
            REFERENCES ref.process_statuses
            (
                process_type_code,
                status_code
            ),

        CONSTRAINT FK_allowed_transitions_to_status
            FOREIGN KEY
            (
                process_type_code,
                to_status_code
            )
            REFERENCES ref.process_statuses
            (
                process_type_code,
                status_code
            ),

        CONSTRAINT FK_allowed_transitions_transition_type
            FOREIGN KEY (transition_type_code)
            REFERENCES ref.transition_types
                (transition_type_code),

        CONSTRAINT CK_allowed_transitions_different_statuses
            CHECK
            (
                from_status_code IS NULL
                OR from_status_code <> to_status_code
            )
    );

    PRINT N'Created table: ref.allowed_status_transitions';
END
ELSE
BEGIN
    PRINT N'Table already exists: ref.allowed_status_transitions';
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
        N'transition_types',
        N'allowed_status_transitions'
    )
GROUP BY
    t.schema_id,
    t.name
ORDER BY
    t.name;
GO