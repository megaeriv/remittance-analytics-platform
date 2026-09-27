/*
Purpose:
    Insert and maintain the business processes that have
    controlled status values in the NovaPay platform.

Behaviour:
    Existing process records are updated.
    Missing process records are inserted.
    Existing records are not duplicated.
*/

USE [NovaPayAnalytics];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE @process_types TABLE
(
    process_type_code VARCHAR(50) NOT NULL PRIMARY KEY,
    process_type_name NVARCHAR(100) NOT NULL,
    process_description NVARCHAR(500) NULL,
    is_active BIT NOT NULL
);

INSERT INTO @process_types
(
    process_type_code,
    process_type_name,
    process_description,
    is_active
)
VALUES
(
    'RegistrationAttempt',
    N'Registration attempt',
    N'A customer journey from starting registration to completion, abandonment or failure.',
    1
),
(
    'TransactionAttempt',
    N'Transaction attempt',
    N'A customer journey while preparing a transfer before an official transaction is created.',
    1
),
(
    'CustomerAccount',
    N'Customer account',
    N'The operational standing of a registered NovaPay customer account.',
    1
),
(
    'CustomerDocument',
    N'Customer document',
    N'The review and validity state of an identity, address or source-of-funds document.',
    1
),
(
    'ComplianceRequirement',
    N'Compliance requirement',
    N'A requirement for evidence, review, approval, waiver or withdrawal.',
    1
),
(
    'Transaction',
    N'Remittance transaction',
    N'The overall remittance instruction from initiation through payment, processing and final outcome.',
    1
),
(
    'FundingPayment',
    N'Funding payment',
    N'A customer payment attempt used to fund a remittance transaction.',
    1
),
(
    'BeneficiaryPayout',
    N'Beneficiary payout',
    N'An attempt to deliver remittance funds to a beneficiary through a payout partner.',
    1
),
(
    'Refund',
    N'Customer refund',
    N'A separate instruction to return confirmed customer funds.',
    1
),
(
    'ComplianceReview',
    N'Compliance review',
    N'A compliance case from opening and assignment through decision and closure.',
    1
);

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE target
    SET
        target.process_type_name =
            source.process_type_name,
        target.process_description =
            source.process_description,
        target.is_active =
            source.is_active
    FROM ref.process_types AS target
    INNER JOIN @process_types AS source
        ON target.process_type_code =
           source.process_type_code;

    INSERT INTO ref.process_types
    (
        process_type_code,
        process_type_name,
        process_description,
        is_active
    )
    SELECT
        source.process_type_code,
        source.process_type_name,
        source.process_description,
        source.is_active
    FROM @process_types AS source
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM ref.process_types AS target
        WHERE target.process_type_code =
              source.process_type_code
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
    process_type_code,
    process_type_name,
    is_active,
    created_at_utc
FROM ref.process_types
ORDER BY process_type_code;
GO