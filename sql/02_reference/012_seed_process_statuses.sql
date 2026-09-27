/*
Purpose:
    Insert and maintain the valid status values for each
    NovaPay business process.

Important:
    is_terminal identifies a status that normally ends the process.
    Exceptional or corrective transitions may still be documented
    separately in the allowed-transition reference table.
*/

USE [NovaPayAnalytics];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE @process_statuses TABLE
(
    process_type_code VARCHAR(50) NOT NULL,
    status_code VARCHAR(60) NOT NULL,
    status_name NVARCHAR(100) NOT NULL,
    status_description NVARCHAR(500) NULL,
    is_terminal BIT NOT NULL,
    is_active BIT NOT NULL,
    display_order SMALLINT NOT NULL,

    PRIMARY KEY
    (
        process_type_code,
        status_code
    )
);

INSERT INTO @process_statuses
(
    process_type_code,
    status_code,
    status_name,
    status_description,
    is_terminal,
    is_active,
    display_order
)
VALUES

-- Registration attempt: 5 statuses
('RegistrationAttempt', 'InProgress',
 N'In progress', N'Registration is actively being completed.',
 0, 1, 1),
('RegistrationAttempt', 'Abandoned',
 N'Abandoned', N'No activity occurred for 20 consecutive minutes before completion.',
 0, 1, 2),
('RegistrationAttempt', 'Resumed',
 N'Resumed', N'The customer returned to a resumable registration journey.',
 0, 1, 3),
('RegistrationAttempt', 'Completed',
 N'Completed', N'The customer account was created successfully.',
 1, 1, 4),
('RegistrationAttempt', 'Failed',
 N'Failed', N'Registration ended because of an unrecoverable error.',
 1, 1, 5),

-- Transaction attempt: 4 statuses
('TransactionAttempt', 'InProgress',
 N'In progress', N'The customer is preparing a transfer instruction.',
 0, 1, 1),
('TransactionAttempt', 'IncompleteDraft',
 N'Incomplete draft', N'The attempt was inactive for 20 minutes before submission.',
 0, 1, 2),
('TransactionAttempt', 'Submitted',
 N'Submitted', N'The attempt created an official transaction reference.',
 1, 1, 3),
('TransactionAttempt', 'Expired',
 N'Expired', N'The incomplete draft exceeded its permitted resumption period.',
 1, 1, 4),

-- Customer account: 5 statuses
('CustomerAccount', 'PendingVerification',
 N'Pending verification', N'The account exists but initial identity requirements are incomplete.',
 0, 1, 1),
('CustomerAccount', 'Active',
 N'Active', N'The account is permitted to use normal NovaPay services.',
 0, 1, 2),
('CustomerAccount', 'Restricted',
 N'Restricted', N'The account has limited access because of a requirement or review.',
 0, 1, 3),
('CustomerAccount', 'Suspended',
 N'Suspended', N'The account is temporarily prevented from normal activity.',
 0, 1, 4),
('CustomerAccount', 'Closed',
 N'Closed', N'The customer account has been closed.',
 1, 1, 5),

-- Customer document: 8 statuses
('CustomerDocument', 'Submitted',
 N'Submitted', N'The customer submitted a document.',
 0, 1, 1),
('CustomerDocument', 'AutomatedReview',
 N'Automated review', N'Automated document checks are in progress.',
 0, 1, 2),
('CustomerDocument', 'ManualReview',
 N'Manual review', N'A reviewer is assessing the document.',
 0, 1, 3),
('CustomerDocument', 'AdditionalInformationRequired',
 N'Additional information required', N'More or corrected evidence is required.',
 0, 1, 4),
('CustomerDocument', 'Approved',
 N'Approved', N'The document was accepted and is currently valid.',
 0, 1, 5),
('CustomerDocument', 'Rejected',
 N'Rejected', N'The document was not accepted.',
 0, 1, 6),
('CustomerDocument', 'Expired',
 N'Expired', N'The approved document reached the end of its validity.',
 0, 1, 7),
('CustomerDocument', 'Superseded',
 N'Superseded', N'The document was replaced by another document version.',
 1, 1, 8),

-- Compliance requirement: 10 statuses
('ComplianceRequirement', 'Required',
 N'Required', N'A compliance requirement has been triggered.',
 0, 1, 1),
('ComplianceRequirement', 'AwaitingDocument',
 N'Awaiting document', N'NovaPay is waiting for the customer to provide evidence.',
 0, 1, 2),
('ComplianceRequirement', 'Submitted',
 N'Submitted', N'The required evidence was submitted.',
 0, 1, 3),
('ComplianceRequirement', 'UnderReview',
 N'Under review', N'Compliance is reviewing the submitted evidence.',
 0, 1, 4),
('ComplianceRequirement', 'AdditionalInformationRequired',
 N'Additional information required', N'Further evidence is needed.',
 0, 1, 5),
('ComplianceRequirement', 'Approved',
 N'Approved', N'The requirement was satisfied.',
 0, 1, 6),
('ComplianceRequirement', 'Rejected',
 N'Rejected', N'The submitted evidence did not satisfy the requirement.',
 1, 1, 7),
('ComplianceRequirement', 'Waived',
 N'Waived', N'An authorised decision removed the need to satisfy the requirement.',
 1, 1, 8),
('ComplianceRequirement', 'Withdrawn',
 N'Withdrawn', N'Compliance formally withdrew the requirement.',
 1, 1, 9),
('ComplianceRequirement', 'Expired',
 N'Expired', N'Previously approved evidence is no longer current.',
 1, 1, 10),

-- Transaction: 13 statuses
('Transaction', 'Initiated',
 N'Initiated', N'The submitted attempt created a remittance transaction.',
 0, 1, 1),
('Transaction', 'AwaitingPayment',
 N'Awaiting payment', N'NovaPay is waiting for customer funding.',
 0, 1, 2),
('Transaction', 'PaymentConfirmationPending',
 N'Payment confirmation pending', N'Payment confirmation exceeded the normal waiting period.',
 0, 1, 3),
('Transaction', 'PaymentException',
 N'Payment exception', N'Payment remained unresolved beyond the exception threshold.',
 0, 1, 4),
('Transaction', 'PaymentConfirmed',
 N'Payment confirmed', N'Customer funding was confirmed.',
 0, 1, 5),
('Transaction', 'ComplianceHold',
 N'Compliance hold', N'The transaction is waiting for compliance clearance.',
 0, 1, 6),
('Transaction', 'Processing',
 N'Processing', N'The transaction is being processed for beneficiary payout.',
 0, 1, 7),
('Transaction', 'Deposited',
 N'Deposited', N'The beneficiary received the funds.',
 1, 1, 8),
('Transaction', 'Failed',
 N'Failed', N'The transaction cannot continue through its normal processing route.',
 1, 1, 9),
('Transaction', 'Cancelled',
 N'Cancelled', N'The transaction was cancelled.',
 1, 1, 10),
('Transaction', 'RefundPending',
 N'Refund pending', N'A customer refund is required or in progress.',
 0, 1, 11),
('Transaction', 'Refunded',
 N'Refunded', N'The required full refund was completed.',
 1, 1, 12),
('Transaction', 'Reversed',
 N'Reversed', N'A previously completed payout was reversed.',
 1, 1, 13),

-- Funding payment: 10 statuses
('FundingPayment', 'Submitted',
 N'Submitted', N'The customer funding attempt was submitted.',
 0, 1, 1),
('FundingPayment', 'Authorised',
 N'Authorised', N'The payment was authorised but not yet confirmed.',
 0, 1, 2),
('FundingPayment', 'ConfirmationPending',
 N'Confirmation pending', N'Provider confirmation is delayed.',
 0, 1, 3),
('FundingPayment', 'Confirmed',
 N'Confirmed', N'The customer funds were confirmed.',
 0, 1, 4),
('FundingPayment', 'Declined',
 N'Declined', N'The provider declined the payment attempt.',
 1, 1, 5),
('FundingPayment', 'Failed',
 N'Failed', N'The funding attempt ended because of a confirmed technical failure.',
 1, 1, 6),
('FundingPayment', 'Cancelled',
 N'Cancelled', N'The funding attempt was cancelled.',
 1, 1, 7),
('FundingPayment', 'Reversed',
 N'Reversed', N'The provider reversed the payment.',
 1, 1, 8),
('FundingPayment', 'RefundPending',
 N'Refund pending', N'A refund of the confirmed payment is in progress.',
 0, 1, 9),
('FundingPayment', 'Refunded',
 N'Refunded', N'The customer refund was confirmed.',
 1, 1, 10),

-- Beneficiary payout: 7 statuses
('BeneficiaryPayout', 'Submitted',
 N'Submitted', N'The payout instruction was submitted to the partner.',
 0, 1, 1),
('BeneficiaryPayout', 'Accepted',
 N'Accepted', N'The payout partner accepted the request.',
 0, 1, 2),
('BeneficiaryPayout', 'Processing',
 N'Processing', N'The payout partner is processing the request.',
 0, 1, 3),
('BeneficiaryPayout', 'Deposited',
 N'Deposited', N'The beneficiary received the payout.',
 1, 1, 4),
('BeneficiaryPayout', 'Failed',
 N'Failed', N'The partner confirmed that the payout attempt failed.',
 1, 1, 5),
('BeneficiaryPayout', 'Cancelled',
 N'Cancelled', N'The payout attempt was cancelled.',
 1, 1, 6),
('BeneficiaryPayout', 'Reversed',
 N'Reversed', N'The partner reversed a previously deposited payout.',
 1, 1, 7),

-- Refund: 7 statuses
('Refund', 'Requested',
 N'Requested', N'A refund instruction was created.',
 0, 1, 1),
('Refund', 'Approved',
 N'Approved', N'The refund received authorised approval.',
 0, 1, 2),
('Refund', 'Submitted',
 N'Submitted', N'The refund was submitted to the payment provider.',
 0, 1, 3),
('Refund', 'Processing',
 N'Processing', N'The payment provider is processing the refund.',
 0, 1, 4),
('Refund', 'Completed',
 N'Completed', N'The customer refund was completed.',
 1, 1, 5),
('Refund', 'Failed',
 N'Failed', N'The refund attempt failed and may require an authorised retry.',
 0, 1, 6),
('Refund', 'Cancelled',
 N'Cancelled', N'The refund request was cancelled.',
 1, 1, 7),

-- Compliance review: 8 statuses
('ComplianceReview', 'Opened',
 N'Opened', N'The compliance review was created.',
 0, 1, 1),
('ComplianceReview', 'Assigned',
 N'Assigned', N'The review was assigned to a reviewer.',
 0, 1, 2),
('ComplianceReview', 'UnderReview',
 N'Under review', N'The compliance assessment is in progress.',
 0, 1, 3),
('ComplianceReview', 'AdditionalInformationRequired',
 N'Additional information required', N'Further customer evidence is required.',
 0, 1, 4),
('ComplianceReview', 'Escalated',
 N'Escalated', N'The case requires senior or specialist review.',
 0, 1, 5),
('ComplianceReview', 'Approved',
 N'Approved', N'The review cleared the case.',
 0, 1, 6),
('ComplianceReview', 'Rejected',
 N'Rejected', N'The review rejected the case.',
 0, 1, 7),
('ComplianceReview', 'Closed',
 N'Closed', N'The review was administratively closed.',
 1, 1, 8);

IF
(
    SELECT COUNT(*)
    FROM @process_statuses
) <> 77
BEGIN
    THROW 50001, 'The status seed must contain exactly 77 rows.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE target
    SET
        target.status_name =
            source.status_name,
        target.status_description =
            source.status_description,
        target.is_terminal =
            source.is_terminal,
        target.is_active =
            source.is_active,
        target.display_order =
            source.display_order
    FROM ref.process_statuses AS target
    INNER JOIN @process_statuses AS source
        ON target.process_type_code =
           source.process_type_code
       AND target.status_code =
           source.status_code;

    INSERT INTO ref.process_statuses
    (
        process_type_code,
        status_code,
        status_name,
        status_description,
        is_terminal,
        is_active,
        display_order
    )
    SELECT
        source.process_type_code,
        source.status_code,
        source.status_name,
        source.status_description,
        source.is_terminal,
        source.is_active,
        source.display_order
    FROM @process_statuses AS source
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM ref.process_statuses AS target
        WHERE target.process_type_code =
              source.process_type_code
          AND target.status_code =
              source.status_code
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
    COUNT(*) AS status_count,
    SUM
    (
        CASE
            WHEN is_terminal = 1 THEN 1
            ELSE 0
        END
    ) AS normally_terminal_count
FROM ref.process_statuses
GROUP BY process_type_code
ORDER BY process_type_code;
GO

SELECT
    COUNT(*) AS total_status_count
FROM ref.process_statuses;
GO