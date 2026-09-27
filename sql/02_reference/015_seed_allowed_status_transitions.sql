/*
Purpose:
    Insert and maintain all 143 allowed status transitions defined for
    the NovaPay Remittance Analytics Platform.

Rule:
    A transition is valid only when a matching active row exists in
    ref.allowed_status_transitions. An omitted transition is invalid.
*/

USE [NovaPayAnalytics];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE @transitions TABLE
(
    process_type_code VARCHAR(50) NOT NULL,
    from_status_code VARCHAR(60) NULL,
    to_status_code VARCHAR(60) NOT NULL,
    transition_type_code VARCHAR(30) NOT NULL,
    requires_reason BIT NOT NULL,
    requires_approval BIT NOT NULL,
    creates_exception BIT NOT NULL,
    is_terminal_transition BIT NOT NULL,
    transition_notes NVARCHAR(500) NULL,
    is_active BIT NOT NULL
);

INSERT INTO @transitions
(
    process_type_code,
    from_status_code,
    to_status_code,
    transition_type_code,
    requires_reason,
    requires_approval,
    creates_exception,
    is_terminal_transition,
    transition_notes,
    is_active
)
VALUES

-- Registration attempt: 8
('RegistrationAttempt', NULL, 'InProgress', 'Initial', 0, 0, 0, 0, N'Registration attempt begins.', 1),
('RegistrationAttempt', 'InProgress', 'Completed', 'Normal', 0, 0, 0, 1, N'Customer account created.', 1),
('RegistrationAttempt', 'InProgress', 'Abandoned', 'Exception', 0, 0, 0, 0, N'Twenty minutes without activity.', 1),
('RegistrationAttempt', 'InProgress', 'Failed', 'Exception', 1, 0, 1, 1, N'Unrecoverable technical or validation failure.', 1),
('RegistrationAttempt', 'Abandoned', 'Resumed', 'Recovery', 0, 0, 0, 0, N'Customer returns within the resumption period.', 1),
('RegistrationAttempt', 'Resumed', 'Completed', 'Normal', 0, 0, 0, 1, N'Resumed registration completes.', 1),
('RegistrationAttempt', 'Resumed', 'Abandoned', 'Exception', 0, 0, 0, 0, N'Resumed registration becomes inactive.', 1),
('RegistrationAttempt', 'Resumed', 'Failed', 'Exception', 1, 0, 1, 1, N'Resumed registration fails.', 1),

-- Transaction attempt: 5
('TransactionAttempt', NULL, 'InProgress', 'Initial', 0, 0, 0, 0, N'Customer starts the transfer journey.', 1),
('TransactionAttempt', 'InProgress', 'Submitted', 'Normal', 0, 0, 0, 1, N'Submission creates a transaction identifier.', 1),
('TransactionAttempt', 'InProgress', 'IncompleteDraft', 'Exception', 0, 0, 0, 0, N'Twenty minutes without activity.', 1),
('TransactionAttempt', 'IncompleteDraft', 'InProgress', 'Recovery', 0, 0, 0, 0, N'Customer resumes the saved attempt.', 1),
('TransactionAttempt', 'IncompleteDraft', 'Expired', 'Terminal', 0, 0, 0, 1, N'Resumption window ends.', 1),

-- Customer account: 13
('CustomerAccount', NULL, 'PendingVerification', 'Initial', 0, 0, 0, 0, N'Account created.', 1),
('CustomerAccount', 'PendingVerification', 'Active', 'Normal', 0, 0, 0, 0, N'Initial identity requirement satisfied.', 1),
('CustomerAccount', 'PendingVerification', 'Restricted', 'Exception', 1, 1, 0, 0, N'Additional review or restriction required.', 1),
('CustomerAccount', 'PendingVerification', 'Closed', 'Terminal', 1, 1, 0, 1, N'Onboarding rejected or customer withdraws.', 1),
('CustomerAccount', 'Active', 'Restricted', 'Exception', 1, 1, 0, 0, N'Compliance requirement or risk restriction.', 1),
('CustomerAccount', 'Active', 'Suspended', 'Exception', 1, 1, 0, 0, N'Stronger temporary restriction.', 1),
('CustomerAccount', 'Active', 'Closed', 'Terminal', 1, 1, 0, 1, N'Account closure.', 1),
('CustomerAccount', 'Restricted', 'Active', 'Recovery', 1, 1, 0, 0, N'Restriction resolved.', 1),
('CustomerAccount', 'Restricted', 'Suspended', 'Exception', 1, 1, 0, 0, N'Risk escalates.', 1),
('CustomerAccount', 'Restricted', 'Closed', 'Terminal', 1, 1, 0, 1, N'Account closed.', 1),
('CustomerAccount', 'Suspended', 'Active', 'Recovery', 1, 1, 0, 0, N'Authorised reinstatement.', 1),
('CustomerAccount', 'Suspended', 'Restricted', 'Recovery', 1, 1, 0, 0, N'Partial reinstatement.', 1),
('CustomerAccount', 'Suspended', 'Closed', 'Terminal', 1, 1, 0, 1, N'Account closed.', 1),

-- Customer document: 16
('CustomerDocument', NULL, 'Submitted', 'Initial', 0, 0, 0, 0, N'Document submitted.', 1),
('CustomerDocument', 'Submitted', 'AutomatedReview', 'Normal', 0, 0, 0, 0, N'Automated checks begin.', 1),
('CustomerDocument', 'Submitted', 'ManualReview', 'Normal', 0, 0, 0, 0, N'Routed directly to a reviewer.', 1),
('CustomerDocument', 'Submitted', 'Rejected', 'Exception', 1, 0, 0, 0, N'Submission is invalid or unacceptable.', 1),
('CustomerDocument', 'AutomatedReview', 'Approved', 'Normal', 0, 0, 0, 0, N'Automated approval.', 1),
('CustomerDocument', 'AutomatedReview', 'ManualReview', 'Normal', 0, 0, 0, 0, N'Human judgement required.', 1),
('CustomerDocument', 'AutomatedReview', 'AdditionalInformationRequired', 'Exception', 1, 0, 0, 0, N'More evidence required.', 1),
('CustomerDocument', 'AutomatedReview', 'Rejected', 'Exception', 1, 0, 0, 0, N'Automated checks reject the document.', 1),
('CustomerDocument', 'ManualReview', 'Approved', 'Normal', 0, 0, 0, 0, N'Reviewer approves the document.', 1),
('CustomerDocument', 'ManualReview', 'AdditionalInformationRequired', 'Exception', 1, 0, 0, 0, N'Reviewer requests more information.', 1),
('CustomerDocument', 'ManualReview', 'Rejected', 'Exception', 1, 0, 0, 0, N'Reviewer rejects the document.', 1),
('CustomerDocument', 'AdditionalInformationRequired', 'Submitted', 'Recovery', 0, 0, 0, 0, N'Corrected or additional evidence submitted.', 1),
('CustomerDocument', 'Approved', 'Expired', 'Terminal', 0, 0, 0, 0, N'Validity period ends.', 1),
('CustomerDocument', 'Approved', 'Superseded', 'Terminal', 1, 0, 0, 1, N'Replaced before expiry.', 1),
('CustomerDocument', 'Rejected', 'Superseded', 'Terminal', 1, 0, 0, 1, N'A new document version replaces it.', 1),
('CustomerDocument', 'Expired', 'Superseded', 'Terminal', 0, 0, 0, 1, N'A renewed document replaces it.', 1),

-- Compliance requirement: 14
('ComplianceRequirement', NULL, 'Required', 'Initial', 0, 0, 0, 0, N'Requirement triggered.', 1),
('ComplianceRequirement', 'Required', 'AwaitingDocument', 'Normal', 0, 0, 0, 0, N'Customer notified.', 1),
('ComplianceRequirement', 'Required', 'Waived', 'Manual', 1, 1, 0, 1, N'Authorised waiver.', 1),
('ComplianceRequirement', 'Required', 'Withdrawn', 'Manual', 1, 1, 0, 1, N'Compliance withdraws requirement.', 1),
('ComplianceRequirement', 'AwaitingDocument', 'Submitted', 'Normal', 0, 0, 0, 0, N'Customer provides evidence.', 1),
('ComplianceRequirement', 'AwaitingDocument', 'Waived', 'Manual', 1, 1, 0, 1, N'Requirement waived.', 1),
('ComplianceRequirement', 'AwaitingDocument', 'Withdrawn', 'Manual', 1, 1, 0, 1, N'Requirement withdrawn.', 1),
('ComplianceRequirement', 'Submitted', 'UnderReview', 'Normal', 0, 0, 0, 0, N'Review begins.', 1),
('ComplianceRequirement', 'UnderReview', 'Approved', 'Normal', 0, 0, 0, 0, N'Requirement satisfied.', 1),
('ComplianceRequirement', 'UnderReview', 'Rejected', 'Exception', 1, 0, 0, 1, N'Evidence does not satisfy the requirement.', 1),
('ComplianceRequirement', 'UnderReview', 'AdditionalInformationRequired', 'Exception', 1, 0, 0, 0, N'More evidence needed.', 1),
('ComplianceRequirement', 'UnderReview', 'Waived', 'Manual', 1, 1, 0, 1, N'Authorised waiver.', 1),
('ComplianceRequirement', 'AdditionalInformationRequired', 'Submitted', 'Recovery', 0, 0, 0, 0, N'Customer resubmits evidence.', 1),
('ComplianceRequirement', 'Approved', 'Expired', 'Terminal', 0, 0, 0, 1, N'Approved evidence is no longer current.', 1),

-- Transaction: 28
('Transaction', NULL, 'Initiated', 'Initial', 0, 0, 0, 0, N'Submitted attempt creates transaction.', 1),
('Transaction', 'Initiated', 'AwaitingPayment', 'Normal', 0, 0, 0, 0, N'Funding required.', 1),
('Transaction', 'Initiated', 'ComplianceHold', 'Exception', 1, 0, 0, 0, N'Pre-payment review required.', 1),
('Transaction', 'Initiated', 'Cancelled', 'Terminal', 1, 0, 0, 1, N'Customer or system cancellation.', 1),
('Transaction', 'Initiated', 'Failed', 'Terminal', 1, 0, 1, 1, N'Unrecoverable creation failure.', 1),
('Transaction', 'AwaitingPayment', 'PaymentConfirmationPending', 'Exception', 0, 0, 0, 0, N'Confirmation exceeds two minutes.', 1),
('Transaction', 'AwaitingPayment', 'PaymentConfirmed', 'Normal', 0, 0, 0, 0, N'Funding confirmed.', 1),
('Transaction', 'AwaitingPayment', 'Cancelled', 'Terminal', 1, 0, 0, 1, N'Customer or system cancellation.', 1),
('Transaction', 'AwaitingPayment', 'Failed', 'Terminal', 1, 0, 1, 1, N'Funding process cannot continue.', 1),
('Transaction', 'PaymentConfirmationPending', 'PaymentConfirmed', 'Recovery', 0, 0, 0, 0, N'Delayed confirmation arrives.', 1),
('Transaction', 'PaymentConfirmationPending', 'PaymentException', 'Exception', 1, 0, 1, 0, N'Pending for more than 24 hours.', 1),
('Transaction', 'PaymentConfirmationPending', 'Cancelled', 'Terminal', 1, 1, 1, 1, N'Cancelled while payment remains unresolved.', 1),
('Transaction', 'PaymentException', 'PaymentConfirmed', 'Recovery', 1, 0, 1, 0, N'Late confirmation; reconciliation required.', 1),
('Transaction', 'PaymentException', 'Cancelled', 'Terminal', 1, 1, 1, 1, N'Transaction cancelled.', 1),
('Transaction', 'PaymentException', 'Failed', 'Terminal', 1, 1, 1, 1, N'Confirmed unrecoverable failure.', 1),
('Transaction', 'PaymentConfirmed', 'ComplianceHold', 'Exception', 1, 0, 0, 0, N'Threshold or risk review required.', 1),
('Transaction', 'PaymentConfirmed', 'Processing', 'Normal', 0, 0, 0, 0, N'Ready for beneficiary payout.', 1),
('Transaction', 'PaymentConfirmed', 'Cancelled', 'Terminal', 1, 1, 1, 1, N'Authorised cancellation; refund may be required.', 1),
('Transaction', 'ComplianceHold', 'Processing', 'Recovery', 0, 1, 0, 0, N'Compliance clears transaction.', 1),
('Transaction', 'ComplianceHold', 'Cancelled', 'Terminal', 1, 1, 0, 1, N'Compliance rejects or customer withdraws.', 1),
('Transaction', 'Processing', 'Deposited', 'Terminal', 0, 0, 0, 1, N'Beneficiary receives funds.', 1),
('Transaction', 'Processing', 'Failed', 'Terminal', 1, 0, 1, 1, N'No further payout retry will occur.', 1),
('Transaction', 'Processing', 'Cancelled', 'Terminal', 1, 1, 1, 1, N'Allowed only before confirmed payout.', 1),
('Transaction', 'Deposited', 'RefundPending', 'Exception', 1, 1, 1, 0, N'Exceptional corrective refund.', 1),
('Transaction', 'Deposited', 'Reversed', 'Exception', 1, 0, 1, 1, N'Payout reversal confirmed.', 1),
('Transaction', 'Failed', 'RefundPending', 'Recovery', 1, 1, 1, 0, N'Customer paid and refund is required.', 1),
('Transaction', 'Cancelled', 'RefundPending', 'Recovery', 1, 1, 1, 0, N'Customer paid before cancellation.', 1),
('Transaction', 'RefundPending', 'Refunded', 'Terminal', 0, 0, 0, 1, N'Full refund completed.', 1),

-- Funding payment: 20
('FundingPayment', NULL, 'Submitted', 'Initial', 0, 0, 0, 0, N'Funding attempt submitted.', 1),
('FundingPayment', 'Submitted', 'Authorised', 'Normal', 0, 0, 0, 0, N'Payment authorised but not confirmed.', 1),
('FundingPayment', 'Submitted', 'ConfirmationPending', 'Exception', 0, 0, 0, 0, N'Provider confirmation delayed.', 1),
('FundingPayment', 'Submitted', 'Confirmed', 'Normal', 0, 0, 0, 0, N'Immediate confirmation.', 1),
('FundingPayment', 'Submitted', 'Declined', 'Terminal', 1, 0, 0, 1, N'Provider declines attempt.', 1),
('FundingPayment', 'Submitted', 'Failed', 'Terminal', 1, 0, 1, 1, N'Technical failure confirmed.', 1),
('FundingPayment', 'Submitted', 'Cancelled', 'Terminal', 1, 0, 0, 1, N'Attempt cancelled.', 1),
('FundingPayment', 'Authorised', 'ConfirmationPending', 'Exception', 0, 0, 0, 0, N'Confirmation delayed.', 1),
('FundingPayment', 'Authorised', 'Confirmed', 'Normal', 0, 0, 0, 0, N'Funds confirmed.', 1),
('FundingPayment', 'Authorised', 'Declined', 'Terminal', 1, 0, 0, 1, N'Authorisation not completed.', 1),
('FundingPayment', 'Authorised', 'Reversed', 'Terminal', 1, 0, 1, 1, N'Authorisation reversed.', 1),
('FundingPayment', 'ConfirmationPending', 'Confirmed', 'Recovery', 0, 0, 0, 0, N'Late confirmation arrives.', 1),
('FundingPayment', 'ConfirmationPending', 'Declined', 'Terminal', 1, 0, 0, 1, N'Provider confirms decline.', 1),
('FundingPayment', 'ConfirmationPending', 'Failed', 'Terminal', 1, 0, 1, 1, N'Provider confirms failure.', 1),
('FundingPayment', 'ConfirmationPending', 'Cancelled', 'Terminal', 1, 1, 1, 1, N'Cancelled while unresolved.', 1),
('FundingPayment', 'Confirmed', 'RefundPending', 'Normal', 1, 1, 0, 0, N'Refund initiated.', 1),
('FundingPayment', 'Confirmed', 'Reversed', 'Exception', 1, 0, 1, 1, N'Provider reverses payment.', 1),
('FundingPayment', 'Cancelled', 'Confirmed', 'Exception', 1, 0, 1, 0, N'Late confirmation; reconciliation required.', 1),
('FundingPayment', 'RefundPending', 'Refunded', 'Terminal', 0, 0, 0, 1, N'Refund confirmed.', 1),
('FundingPayment', 'RefundPending', 'Failed', 'Exception', 1, 0, 1, 1, N'Refund attempt failed.', 1),

-- Beneficiary payout: 13
('BeneficiaryPayout', NULL, 'Submitted', 'Initial', 0, 0, 0, 0, N'Payout attempt submitted.', 1),
('BeneficiaryPayout', 'Submitted', 'Accepted', 'Normal', 0, 0, 0, 0, N'Partner accepts request.', 1),
('BeneficiaryPayout', 'Submitted', 'Processing', 'Normal', 0, 0, 0, 0, N'Partner begins processing.', 1),
('BeneficiaryPayout', 'Submitted', 'Failed', 'Terminal', 1, 0, 1, 1, N'Partner confirms failure.', 1),
('BeneficiaryPayout', 'Submitted', 'Cancelled', 'Terminal', 1, 0, 0, 1, N'Cancelled before processing.', 1),
('BeneficiaryPayout', 'Accepted', 'Processing', 'Normal', 0, 0, 0, 0, N'Processing begins.', 1),
('BeneficiaryPayout', 'Accepted', 'Failed', 'Terminal', 1, 0, 1, 1, N'Partner confirms failure.', 1),
('BeneficiaryPayout', 'Accepted', 'Cancelled', 'Terminal', 1, 0, 0, 1, N'Cancellation confirmed.', 1),
('BeneficiaryPayout', 'Processing', 'Deposited', 'Terminal', 0, 0, 0, 1, N'Beneficiary receives funds.', 1),
('BeneficiaryPayout', 'Processing', 'Failed', 'Terminal', 1, 0, 1, 1, N'Partner confirms failure.', 1),
('BeneficiaryPayout', 'Processing', 'Cancelled', 'Terminal', 1, 1, 1, 1, N'Cancelled before confirmed deposit.', 1),
('BeneficiaryPayout', 'Cancelled', 'Deposited', 'Exception', 1, 0, 1, 1, N'Late deposit; urgent reconciliation required.', 1),
('BeneficiaryPayout', 'Deposited', 'Reversed', 'Exception', 1, 0, 1, 1, N'Partner confirms payout reversal.', 1),

-- Refund: 11
('Refund', NULL, 'Requested', 'Initial', 0, 0, 0, 0, N'Refund instruction created.', 1),
('Refund', 'Requested', 'Approved', 'Normal', 1, 1, 0, 0, N'Authorised approval.', 1),
('Refund', 'Requested', 'Cancelled', 'Terminal', 1, 1, 0, 1, N'Request withdrawn or rejected.', 1),
('Refund', 'Approved', 'Submitted', 'Normal', 0, 0, 0, 0, N'Sent to payment provider.', 1),
('Refund', 'Approved', 'Cancelled', 'Terminal', 1, 1, 0, 1, N'Approval withdrawn before submission.', 1),
('Refund', 'Submitted', 'Processing', 'Normal', 0, 0, 0, 0, N'Provider processing refund.', 1),
('Refund', 'Submitted', 'Completed', 'Terminal', 0, 0, 0, 1, N'Immediate completion.', 1),
('Refund', 'Submitted', 'Failed', 'Exception', 1, 0, 1, 0, N'Provider confirms failure.', 1),
('Refund', 'Processing', 'Completed', 'Terminal', 0, 0, 0, 1, N'Customer refund completed.', 1),
('Refund', 'Processing', 'Failed', 'Exception', 1, 0, 1, 0, N'Refund fails.', 1),
('Refund', 'Failed', 'Submitted', 'Recovery', 1, 1, 0, 0, N'Authorised retry.', 1),

-- Compliance review: 15
('ComplianceReview', NULL, 'Opened', 'Initial', 0, 0, 0, 0, N'Review created.', 1),
('ComplianceReview', 'Opened', 'Assigned', 'Normal', 0, 0, 0, 0, N'Reviewer assigned.', 1),
('ComplianceReview', 'Opened', 'UnderReview', 'Normal', 0, 0, 0, 0, N'Review begins immediately.', 1),
('ComplianceReview', 'Assigned', 'UnderReview', 'Normal', 0, 0, 0, 0, N'Assigned reviewer begins work.', 1),
('ComplianceReview', 'Assigned', 'Escalated', 'Exception', 1, 0, 0, 0, N'Senior or specialist review needed.', 1),
('ComplianceReview', 'UnderReview', 'AdditionalInformationRequired', 'Exception', 1, 0, 0, 0, N'Customer evidence required.', 1),
('ComplianceReview', 'UnderReview', 'Approved', 'Normal', 0, 0, 0, 0, N'Review clears case.', 1),
('ComplianceReview', 'UnderReview', 'Rejected', 'Terminal', 1, 1, 0, 0, N'Review rejects case.', 1),
('ComplianceReview', 'UnderReview', 'Escalated', 'Exception', 1, 0, 0, 0, N'Higher authority required.', 1),
('ComplianceReview', 'AdditionalInformationRequired', 'UnderReview', 'Recovery', 0, 0, 0, 0, N'Evidence received; review resumes.', 1),
('ComplianceReview', 'Escalated', 'UnderReview', 'Recovery', 0, 0, 0, 0, N'Escalated case returns to review.', 1),
('ComplianceReview', 'Escalated', 'Approved', 'Normal', 1, 1, 0, 0, N'Senior approval.', 1),
('ComplianceReview', 'Escalated', 'Rejected', 'Terminal', 1, 1, 0, 0, N'Senior rejection.', 1),
('ComplianceReview', 'Approved', 'Closed', 'Terminal', 0, 0, 0, 1, N'Review administratively closed.', 1),
('ComplianceReview', 'Rejected', 'Closed', 'Terminal', 0, 0, 0, 1, N'Review administratively closed.', 1);

IF (SELECT COUNT(*) FROM @transitions) <> 143
BEGIN
    THROW 50002, 'The transition seed must contain exactly 143 rows.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE target
    SET
        target.transition_type_code = source.transition_type_code,
        target.requires_reason = source.requires_reason,
        target.requires_approval = source.requires_approval,
        target.creates_exception = source.creates_exception,
        target.is_terminal_transition = source.is_terminal_transition,
        target.transition_notes = source.transition_notes,
        target.is_active = source.is_active
    FROM ref.allowed_status_transitions AS target
    INNER JOIN @transitions AS source
        ON target.process_type_code = source.process_type_code
       AND
       (
           target.from_status_code = source.from_status_code
           OR
           (
               target.from_status_code IS NULL
               AND source.from_status_code IS NULL
           )
       )
       AND target.to_status_code = source.to_status_code;

    INSERT INTO ref.allowed_status_transitions
    (
        process_type_code,
        from_status_code,
        to_status_code,
        transition_type_code,
        requires_reason,
        requires_approval,
        creates_exception,
        is_terminal_transition,
        transition_notes,
        is_active
    )
    SELECT
        source.process_type_code,
        source.from_status_code,
        source.to_status_code,
        source.transition_type_code,
        source.requires_reason,
        source.requires_approval,
        source.creates_exception,
        source.is_terminal_transition,
        source.transition_notes,
        source.is_active
    FROM @transitions AS source
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM ref.allowed_status_transitions AS target
        WHERE target.process_type_code = source.process_type_code
          AND
          (
              target.from_status_code = source.from_status_code
              OR
              (
                  target.from_status_code IS NULL
                  AND source.from_status_code IS NULL
              )
          )
          AND target.to_status_code = source.to_status_code
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
    COUNT(*) AS transition_count
FROM ref.allowed_status_transitions
GROUP BY process_type_code
ORDER BY process_type_code;
GO

SELECT
    COUNT(*) AS total_transition_count
FROM ref.allowed_status_transitions;
GO
