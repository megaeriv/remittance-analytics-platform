/*
Purpose:
    Build and validate the complete NovaPay staging layer.

Design:
    - src preserves operational records.
    - stg standardises business interpretation without altering src.
    - views keep the layer reproducible and expose lineage back to src.
*/

USE [NovaPayAnalytics];
GO
SET NOCOUNT ON;
GO

CREATE OR ALTER VIEW stg.registration_attempts
AS
SELECT
    registration_attempt_id,
    session_id,
    started_at_utc,
    last_activity_at_utc,
    completed_at_utc,
    last_completed_step,
    attempt_status,
    acquisition_channel,
    device_type,
    country_code,
    customer_id,
    DATEDIFF_BIG(SECOND, started_at_utc,
        COALESCE(completed_at_utc, last_activity_at_utc)) AS journey_duration_seconds,
    CAST(CASE WHEN attempt_status = 'Completed' THEN 1 ELSE 0 END AS BIT)
        AS is_completed_registration,
    CAST(CASE WHEN attempt_status <> 'Completed' THEN 1 ELSE 0 END AS BIT)
        AS is_incomplete_registration
FROM src.registration_attempts;
GO

CREATE OR ALTER VIEW stg.customers
AS
WITH first_success AS
(
    SELECT customer_id, MIN(deposited_at_utc) AS first_deposited_at_utc
    FROM src.transactions
    WHERE current_transaction_status = 'Deposited'
    GROUP BY customer_id
)
SELECT
    c.customer_id,
    c.registration_attempt_id,
    c.registration_timestamp_utc,
    c.first_name,
    c.last_name,
    CONCAT(c.first_name, N' ', c.last_name) AS customer_name,
    c.date_of_birth,
    c.country_of_residence_code,
    c.preferred_currency,
    c.account_status,
    c.identity_status,
    c.transaction_eligibility_status,
    c.acquisition_channel,
    c.marketing_consent,
    f.first_deposited_at_utc,
    CAST(CASE WHEN f.first_deposited_at_utc IS NOT NULL THEN 1 ELSE 0 END AS BIT)
        AS has_activated,
    CASE WHEN f.first_deposited_at_utc IS NULL THEN NULL
         ELSE DATEDIFF_BIG(SECOND, c.registration_timestamp_utc,
                           f.first_deposited_at_utc) END
        AS seconds_to_first_successful_transfer
FROM src.customers AS c
LEFT JOIN first_success AS f ON f.customer_id = c.customer_id;
GO

CREATE OR ALTER VIEW stg.customer_documents
AS
SELECT
    document_id,
    customer_id,
    compliance_requirement_id,
    document_category,
    document_type,
    issuing_country_code,
    submitted_at_utc,
    document_issue_date,
    document_expiry_date,
    current_verification_status,
    current_status_at_utc,
    is_current_document,
    superseded_by_document_id,
    DATEDIFF_BIG(SECOND, submitted_at_utc, current_status_at_utc)
        AS verification_duration_seconds,
    CAST(CASE WHEN current_verification_status = 'Approved'
                   AND is_current_document = 1
                   AND (document_expiry_date IS NULL
                        OR document_expiry_date >= CONVERT(DATE, SYSUTCDATETIME()))
              THEN 1 ELSE 0 END AS BIT) AS is_currently_valid,
    CAST(CASE WHEN document_expiry_date IS NOT NULL
                   AND document_expiry_date < CONVERT(DATE, SYSUTCDATETIME())
              THEN 1 ELSE 0 END AS BIT) AS is_expired
FROM src.customer_documents;
GO

CREATE OR ALTER VIEW stg.compliance_requirements
AS
SELECT
    compliance_requirement_id,
    customer_id,
    requirement_type,
    trigger_type,
    triggered_transaction_id,
    threshold_amount_gbp,
    qualifying_volume_gbp,
    current_requirement_status,
    triggered_at_utc,
    satisfied_at_utc,
    expires_on,
    CASE WHEN satisfied_at_utc IS NULL THEN NULL
         ELSE DATEDIFF_BIG(SECOND, triggered_at_utc, satisfied_at_utc) END
        AS satisfaction_duration_seconds,
    CAST(CASE WHEN current_requirement_status IN
                   ('Required', 'AwaitingDocument', 'Submitted', 'UnderReview')
              THEN 1 ELSE 0 END AS BIT) AS is_open_requirement
FROM src.customer_compliance_requirements;
GO

CREATE OR ALTER VIEW stg.beneficiaries
AS
SELECT
    beneficiary_id,
    customer_id,
    first_name,
    last_name,
    CONCAT(first_name, N' ', last_name) AS beneficiary_name,
    destination_country_code,
    receive_currency,
    collection_method,
    beneficiary_status,
    created_at_utc
FROM src.beneficiaries;
GO

CREATE OR ALTER VIEW stg.referrals
AS
SELECT
    referral_id,
    referrer_customer_id,
    referred_customer_id,
    referral_status,
    invited_at_utc,
    registered_at_utc,
    activated_at_utc,
    reward_status,
    CASE WHEN registered_at_utc IS NULL THEN NULL
         ELSE DATEDIFF_BIG(SECOND, invited_at_utc, registered_at_utc) END
        AS invite_to_registration_seconds,
    CASE WHEN activated_at_utc IS NULL THEN NULL
         ELSE DATEDIFF_BIG(SECOND, registered_at_utc, activated_at_utc) END
        AS registration_to_activation_seconds,
    CAST(CASE WHEN referred_customer_id IS NOT NULL THEN 1 ELSE 0 END AS BIT)
        AS converted_to_customer,
    CAST(CASE WHEN activated_at_utc IS NOT NULL THEN 1 ELSE 0 END AS BIT)
        AS converted_to_activation
FROM src.referrals;
GO

CREATE OR ALTER VIEW stg.transaction_attempts
AS
SELECT
    transaction_attempt_id,
    customer_id,
    started_at_utc,
    last_activity_at_utc,
    last_completed_step,
    send_amount,
    send_currency,
    destination_country_code,
    beneficiary_id,
    collection_method,
    quoted_exchange_rate_id,
    attempt_status,
    transaction_id,
    submitted_at_utc,
    DATEDIFF_BIG(SECOND, started_at_utc,
        COALESCE(submitted_at_utc, last_activity_at_utc)) AS attempt_duration_seconds,
    CAST(CASE WHEN attempt_status = 'Submitted' THEN 1 ELSE 0 END AS BIT)
        AS is_submitted,
    CAST(CASE WHEN attempt_status <> 'Submitted' AND transaction_id IS NULL
              THEN 1 ELSE 0 END AS BIT) AS is_incomplete_attempt,
    CASE
        WHEN attempt_status = 'Submitted' THEN 'Submitted'
        WHEN attempt_status = 'IncompleteDraft' THEN 'CustomerAbandonment'
        ELSE 'OtherIncomplete'
    END AS attempt_outcome_group,
    CAST(CASE WHEN send_amount IS NOT NULL THEN 1 ELSE 0 END AS BIT)
        AS captured_amount,
    CAST(CASE WHEN beneficiary_id IS NOT NULL THEN 1 ELSE 0 END AS BIT)
        AS captured_beneficiary
FROM src.transaction_attempts;
GO

CREATE OR ALTER VIEW stg.payments
AS
SELECT
    payment_attempt_id,
    transaction_id,
    payment_method,
    payment_provider,
    payment_amount,
    payment_currency,
    current_payment_status,
    submitted_at_utc,
    confirmed_at_utc,
    CASE WHEN confirmed_at_utc IS NULL THEN NULL
         ELSE DATEDIFF_BIG(SECOND, submitted_at_utc, confirmed_at_utc) END
        AS confirmation_duration_seconds,
    CAST(CASE WHEN current_payment_status = 'Confirmed' THEN 1 ELSE 0 END AS BIT)
        AS is_confirmed,
    CAST(CASE WHEN current_payment_status IN ('Declined', 'Failed')
              THEN 1 ELSE 0 END AS BIT) AS is_failed_payment
FROM src.payment_attempts;
GO

CREATE OR ALTER VIEW stg.payouts
AS
SELECT
    payout_attempt_id,
    transaction_id,
    payout_partner,
    collection_method,
    payout_amount,
    payout_currency,
    current_payout_status,
    submitted_at_utc,
    completed_at_utc,
    CASE WHEN completed_at_utc IS NULL THEN NULL
         ELSE DATEDIFF_BIG(SECOND, submitted_at_utc, completed_at_utc) END
        AS payout_duration_seconds,
    CAST(CASE WHEN current_payout_status = 'Deposited' THEN 1 ELSE 0 END AS BIT)
        AS is_deposited,
    CAST(CASE WHEN current_payout_status = 'Failed' THEN 1 ELSE 0 END AS BIT)
        AS is_failed_payout
FROM src.payout_attempts;
GO

CREATE OR ALTER VIEW stg.refunds
AS
SELECT
    refund_id,
    transaction_id,
    payment_attempt_id,
    refund_type,
    refund_amount,
    refund_currency,
    refund_reason_code,
    current_refund_status,
    requested_at_utc,
    completed_at_utc,
    CASE WHEN completed_at_utc IS NULL THEN NULL
         ELSE DATEDIFF_BIG(SECOND, requested_at_utc, completed_at_utc) END
        AS refund_duration_seconds,
    CAST(CASE WHEN current_refund_status = 'Completed' THEN 1 ELSE 0 END AS BIT)
        AS is_completed_refund,
    CAST(CASE WHEN refund_type = 'Full' THEN 1 ELSE 0 END AS BIT)
        AS is_full_refund
FROM src.refunds;
GO

CREATE OR ALTER VIEW stg.compliance_reviews
AS
SELECT
    compliance_review_id,
    customer_id,
    transaction_id,
    review_type,
    trigger_rule_code,
    risk_level,
    current_review_status,
    review_outcome,
    opened_at_utc,
    closed_at_utc,
    CASE WHEN closed_at_utc IS NULL THEN NULL
         ELSE DATEDIFF_BIG(SECOND, opened_at_utc, closed_at_utc) END
        AS review_duration_seconds,
    CAST(CASE WHEN closed_at_utc IS NULL THEN 1 ELSE 0 END AS BIT)
        AS is_open_review
FROM src.compliance_reviews;
GO

CREATE OR ALTER VIEW stg.transactions
AS
WITH completed_refunds AS
(
    SELECT
        transaction_id,
        SUM(CASE WHEN current_refund_status = 'Completed'
                 THEN refund_amount ELSE 0 END) AS completed_refund_amount,
        MAX(CASE WHEN current_refund_status = 'Completed'
                  AND refund_type = 'Full' THEN 1 ELSE 0 END)
            AS has_completed_full_refund
    FROM src.refunds
    GROUP BY transaction_id
)
SELECT
    tr.transaction_id,
    tr.transaction_attempt_id,
    tr.customer_id,
    tr.beneficiary_id,
    tr.send_amount,
    tr.send_currency,
    tr.send_amount_gbp_equivalent,
    tr.receive_amount,
    tr.receive_currency,
    tr.transfer_fee,
    tr.customer_exchange_rate,
    tr.market_exchange_rate_id,
    tr.collection_method,
    tr.current_transaction_status,
    tr.initiated_at_utc,
    tr.deposited_at_utc,
    COALESCE(r.completed_refund_amount, 0) AS completed_refund_amount,
    tr.send_amount - COALESCE(r.completed_refund_amount, 0) AS net_send_amount,
    CAST(COALESCE(r.has_completed_full_refund, 0) AS BIT)
        AS has_completed_full_refund,
    CASE WHEN tr.deposited_at_utc IS NULL THEN NULL
         ELSE DATEDIFF_BIG(SECOND, tr.initiated_at_utc, tr.deposited_at_utc) END
        AS completion_duration_seconds,
    CASE WHEN tr.deposited_at_utc IS NULL THEN NULL
         ELSE CONVERT(DECIMAL(19, 4),
              DATEDIFF_BIG(MILLISECOND, tr.initiated_at_utc,
                           tr.deposited_at_utc) / 60000.0) END
        AS completion_duration_minutes,
    CAST(CASE WHEN tr.current_transaction_status = 'Deposited'
              THEN 1 ELSE 0 END AS BIT) AS is_successful_transfer,
    CAST(CASE WHEN tr.current_transaction_status = 'Failed'
              THEN 1 ELSE 0 END AS BIT) AS is_failed_transaction,
    CAST(CASE WHEN tr.current_transaction_status = 'PaymentException'
              THEN 1 ELSE 0 END AS BIT) AS is_payment_exception,
    CAST(CASE WHEN tr.current_transaction_status = 'ComplianceHold'
              THEN 1 ELSE 0 END AS BIT) AS is_compliance_hold,
    CAST(CASE WHEN tr.current_transaction_status = 'Deposited'
                   AND DATEDIFF_BIG(SECOND, tr.initiated_at_utc,
                                    tr.deposited_at_utc) <= 120
              THEN 1 ELSE 0 END AS BIT) AS met_two_minute_target,
    CAST(CASE WHEN tr.current_transaction_status = 'Deposited'
              THEN 1 ELSE 0 END AS BIT) AS qualifies_customer_as_active,
    CONVERT(DATE, tr.initiated_at_utc) AS initiated_date,
    CASE WHEN tr.deposited_at_utc IS NULL THEN NULL
         ELSE CONVERT(DATE, tr.deposited_at_utc) END AS deposited_date
FROM src.transactions AS tr
LEFT JOIN completed_refunds AS r ON r.transaction_id = tr.transaction_id;
GO

CREATE OR ALTER VIEW stg.transaction_status_intervals
AS
WITH sequenced AS
(
    SELECT
        transaction_status_event_id,
        transaction_id,
        source_status,
        canonical_status,
        event_timestamp_utc AS status_started_at_utc,
        LEAD(event_timestamp_utc) OVER
        (
            PARTITION BY transaction_id
            ORDER BY event_timestamp_utc,
                     COALESCE(source_event_sequence, 0),
                     transaction_status_event_id
        ) AS next_status_at_utc,
        reason_code,
        source_system,
        source_event_sequence
    FROM src.transaction_status_history
)
SELECT
    transaction_status_event_id,
    transaction_id,
    source_status,
    canonical_status,
    status_started_at_utc,
    next_status_at_utc AS status_ended_at_utc,
    CASE WHEN next_status_at_utc IS NULL THEN NULL
         ELSE DATEDIFF_BIG(SECOND, status_started_at_utc,
                           next_status_at_utc) END AS status_duration_seconds,
    CAST(CASE WHEN next_status_at_utc IS NULL THEN 1 ELSE 0 END AS BIT)
        AS is_current_status,
    reason_code,
    source_system,
    source_event_sequence
FROM sequenced;
GO

CREATE OR ALTER VIEW stg.payment_status_intervals
AS
WITH sequenced AS
(
    SELECT
        payment_status_event_id,
        payment_attempt_id,
        source_status,
        canonical_status,
        event_timestamp_utc AS status_started_at_utc,
        LEAD(event_timestamp_utc) OVER
        (
            PARTITION BY payment_attempt_id
            ORDER BY event_timestamp_utc, payment_status_event_id
        ) AS next_status_at_utc,
        reason_code,
        source_system
    FROM src.payment_status_history
)
SELECT
    payment_status_event_id,
    payment_attempt_id,
    source_status,
    canonical_status,
    status_started_at_utc,
    next_status_at_utc AS status_ended_at_utc,
    CASE WHEN next_status_at_utc IS NULL THEN NULL
         ELSE DATEDIFF_BIG(SECOND, status_started_at_utc,
                           next_status_at_utc) END AS status_duration_seconds,
    CAST(CASE WHEN next_status_at_utc IS NULL THEN 1 ELSE 0 END AS BIT)
        AS is_current_status,
    reason_code,
    source_system
FROM sequenced;
GO

CREATE OR ALTER VIEW stg.payout_status_intervals
AS
WITH sequenced AS
(
    SELECT
        payout_status_event_id,
        payout_attempt_id,
        source_status,
        canonical_status,
        event_timestamp_utc AS status_started_at_utc,
        LEAD(event_timestamp_utc) OVER
        (
            PARTITION BY payout_attempt_id
            ORDER BY event_timestamp_utc, payout_status_event_id
        ) AS next_status_at_utc,
        reason_code,
        source_system
    FROM src.payout_status_history
)
SELECT
    payout_status_event_id,
    payout_attempt_id,
    source_status,
    canonical_status,
    status_started_at_utc,
    next_status_at_utc AS status_ended_at_utc,
    CASE WHEN next_status_at_utc IS NULL THEN NULL
         ELSE DATEDIFF_BIG(SECOND, status_started_at_utc,
                           next_status_at_utc) END AS status_duration_seconds,
    CAST(CASE WHEN next_status_at_utc IS NULL THEN 1 ELSE 0 END AS BIT)
        AS is_current_status,
    reason_code,
    source_system
FROM sequenced;
GO

DECLARE @checks TABLE
(
    check_number SMALLINT NOT NULL,
    check_name NVARCHAR(200) NOT NULL,
    failed_rows BIGINT NOT NULL
);

INSERT INTO @checks
SELECT 1, N'Expected staging-view count', ABS(COUNT_BIG(*) - 15)
FROM sys.views AS v
INNER JOIN sys.schemas AS s ON s.schema_id = v.schema_id
WHERE s.name = N'stg';

INSERT INTO @checks
SELECT 2, N'Customer row count agrees with source',
       ABS((SELECT COUNT_BIG(*) FROM stg.customers)
         - (SELECT COUNT_BIG(*) FROM src.customers));

INSERT INTO @checks
SELECT 3, N'Transaction row count agrees with source',
       ABS((SELECT COUNT_BIG(*) FROM stg.transactions)
         - (SELECT COUNT_BIG(*) FROM src.transactions));

INSERT INTO @checks
SELECT 4, N'Attempt row count agrees with source',
       ABS((SELECT COUNT_BIG(*) FROM stg.transaction_attempts)
         - (SELECT COUNT_BIG(*) FROM src.transaction_attempts));

INSERT INTO @checks
SELECT 5, N'Incomplete attempts have no transaction', COUNT_BIG(*)
FROM stg.transaction_attempts
WHERE is_incomplete_attempt = 1 AND transaction_id IS NOT NULL;

INSERT INTO @checks
SELECT 6, N'Completion durations are non-negative', COUNT_BIG(*)
FROM stg.transactions
WHERE completion_duration_seconds < 0;

INSERT INTO @checks
SELECT 7, N'Transaction status intervals are non-negative', COUNT_BIG(*)
FROM stg.transaction_status_intervals
WHERE status_duration_seconds < 0;

INSERT INTO @checks
SELECT 8, N'Payment status intervals are non-negative', COUNT_BIG(*)
FROM stg.payment_status_intervals
WHERE status_duration_seconds < 0;

INSERT INTO @checks
SELECT 9, N'Payout status intervals are non-negative', COUNT_BIG(*)
FROM stg.payout_status_intervals
WHERE status_duration_seconds < 0;

INSERT INTO @checks
SELECT 10, N'One current transaction status per transaction', COUNT_BIG(*)
FROM
(
    SELECT transaction_id
    FROM stg.transaction_status_intervals
    WHERE is_current_status = 1
    GROUP BY transaction_id
    HAVING COUNT_BIG(*) <> 1
) AS invalid;

INSERT INTO @checks
SELECT 11, N'Active qualification uses deposited transactions only', COUNT_BIG(*)
FROM stg.transactions
WHERE (qualifies_customer_as_active = 1
       AND current_transaction_status <> 'Deposited')
   OR (qualifies_customer_as_active = 0
       AND current_transaction_status = 'Deposited');

INSERT INTO @checks
SELECT 12, N'Two-minute target flag uses successful transactions only', COUNT_BIG(*)
FROM stg.transactions
WHERE met_two_minute_target = 1 AND is_successful_transfer = 0;

SELECT
    check_number,
    check_name,
    failed_rows,
    CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM @checks
ORDER BY check_number;

SELECT
    current_transaction_status,
    COUNT_BIG(*) AS transaction_count,
    SUM(send_amount_gbp_equivalent) AS gross_volume_gbp,
    AVG(completion_duration_minutes) AS average_completion_minutes
FROM stg.transactions
GROUP BY current_transaction_status
ORDER BY current_transaction_status;

SELECT
    (SELECT COUNT_BIG(*) FROM stg.customers) AS customers,
    (SELECT COUNT_BIG(*) FROM stg.transaction_attempts) AS transaction_attempts,
    (SELECT COUNT_BIG(*) FROM stg.transactions) AS transactions,
    (SELECT COUNT_BIG(*) FROM stg.transactions
     WHERE is_successful_transfer = 1) AS successful_transactions,
    (SELECT COUNT_BIG(DISTINCT customer_id) FROM stg.transactions
     WHERE qualifies_customer_as_active = 1) AS active_customers;

IF EXISTS (SELECT 1 FROM @checks WHERE failed_rows <> 0)
BEGIN
    THROW 51010, 'NovaPay staging validation failed. Review failed_rows.', 1;
END;

PRINT N'NovaPay staging build succeeded: all 15 views created and all validation checks passed.';
GO
