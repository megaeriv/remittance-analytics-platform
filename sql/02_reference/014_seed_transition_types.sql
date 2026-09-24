/*
Purpose:
    Insert and maintain the controlled transition categories
    used by NovaPay status-transition rules.
*/

USE [NovaPayAnalytics];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE @transition_types TABLE
(
    transition_type_code VARCHAR(30) NOT NULL PRIMARY KEY,
    transition_type_name NVARCHAR(100) NOT NULL,
    transition_type_description NVARCHAR(500) NULL,
    is_active BIT NOT NULL
);

INSERT INTO @transition_types
(
    transition_type_code,
    transition_type_name,
    transition_type_description,
    is_active
)
VALUES
(
    'Initial',
    N'Initial',
    N'Creates the first status for a new process record.',
    1
),
(
    'Normal',
    N'Normal',
    N'Represents an expected forward movement in the standard business workflow.',
    1
),
(
    'Exception',
    N'Exception',
    N'Represents movement caused by an operational, technical, compliance or financial exception.',
    1
),
(
    'Recovery',
    N'Recovery',
    N'Represents movement that resolves or continues from an exception condition.',
    1
),
(
    'Manual',
    N'Manual',
    N'Requires an authorised human decision or intervention.',
    1
),
(
    'Terminal',
    N'Terminal',
    N'Explicitly ends the normal lifecycle of the process or attempt.',
    1
);

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE target
    SET
        target.transition_type_name =
            source.transition_type_name,
        target.transition_type_description =
            source.transition_type_description,
        target.is_active =
            source.is_active
    FROM ref.transition_types AS target
    INNER JOIN @transition_types AS source
        ON target.transition_type_code =
           source.transition_type_code;

    INSERT INTO ref.transition_types
    (
        transition_type_code,
        transition_type_name,
        transition_type_description,
        is_active
    )
    SELECT
        source.transition_type_code,
        source.transition_type_name,
        source.transition_type_description,
        source.is_active
    FROM @transition_types AS source
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM ref.transition_types AS target
        WHERE target.transition_type_code =
              source.transition_type_code
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

SELECT
    transition_type_code,
    transition_type_name,
    is_active,
    created_at_utc
FROM ref.transition_types
ORDER BY
    CASE transition_type_code
        WHEN 'Initial' THEN 1
        WHEN 'Normal' THEN 2
        WHEN 'Exception' THEN 3
        WHEN 'Recovery' THEN 4
        WHEN 'Manual' THEN 5
        WHEN 'Terminal' THEN 6
        ELSE 99
    END;
GO