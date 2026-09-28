/*
Purpose:
    Validate the complete synthetic NovaPay source dataset before it is
    accepted into the portfolio repository.

Result:
    Every ERROR check must return zero failed rows. The script throws an
    error at the end if any control fails, making it suitable for repeatable
    command-line and future pipeline testing.
*/

USE [NovaPayAnalytics];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @audit_results TABLE
(
    check_number SMALLINT NOT NULL,
    check_name NVARCHAR(200) NOT NULL,
    failed_rows BIGINT NOT NULL,
    severity VARCHAR(10) NOT NULL
);

/* 1. The implemented source model contains exactly 22 tables. */
INSERT INTO @audit_results
SELECT 1, N'Expected source-table count',
       ABS(COUNT_BIG(*) - 22), 'ERROR'
FROM sys.tables AS t
INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name = N'src';

/* 2. Every source table received at least one synthetic row. */
DECLARE @empty_table_count BIGINT;
SELECT @empty_table_count = COUNT_BIG(*)
FROM
(
    SELECT t.object_id
    FROM sys.tables AS t
    INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
    LEFT JOIN sys.partitions AS p
        ON p.object_id = t.object_id AND p.index_id IN (0, 1)
    WHERE s.name = N'src'
    GROUP BY t.object_id
    HAVING COALESCE(SUM(p.rows), 0) = 0
) AS empty_tables;
INSERT INTO @audit_results VALUES
    (2, N'No empty source tables', @empty_table_count, 'ERROR');

/* 3. Registration completion must agree with customer creation. */
INSERT INTO @audit_results
SELECT 3, N'Completed registration maps to exactly one customer', COUNT_BIG(*), 'ERROR'
FROM src.registration_attempts AS ra
LEFT JOIN src.customers AS c
    ON c.registration_attempt_id = ra.registration_attempt_id
   AND c.customer_id = ra.customer_id
WHERE (ra.attempt_status = 'Completed' AND c.customer_id IS NULL)
   OR (ra.attempt_status <> 'Completed' AND c.customer_id IS NOT NULL);

/* 4. An incomplete transaction attempt must never have a transaction ID. */
INSERT INTO @audit_results
SELECT 4, N'Incomplete attempts have no transaction ID', COUNT_BIG(*), 'ERROR'
FROM src.transaction_attempts
WHERE attempt_status <> 'Submitted'
  AND (transaction_id IS NOT NULL OR submitted_at_utc IS NOT NULL);

/* 5. Every submitted attempt and transaction must point to each other. */
INSERT INTO @audit_results
SELECT 5, N'Submitted attempt and transaction linkage agrees', COUNT_BIG(*), 'ERROR'
FROM src.transaction_attempts AS ta
FULL OUTER JOIN src.transactions AS tr
    ON tr.transaction_attempt_id = ta.transaction_attempt_id
   AND tr.transaction_id = ta.transaction_id
WHERE (ta.attempt_status = 'Submitted' AND tr.transaction_id IS NULL)
   OR (tr.transaction_id IS NOT NULL
       AND (ta.transaction_attempt_id IS NULL OR ta.attempt_status <> 'Submitted'));

/* 6. A customer's transaction cannot use another customer's beneficiary. */
INSERT INTO @audit_results
SELECT 6, N'Transaction beneficiary belongs to transaction customer', COUNT_BIG(*), 'ERROR'
FROM src.transactions AS tr
INNER JOIN src.beneficiaries AS b ON b.beneficiary_id = tr.beneficiary_id
WHERE b.customer_id <> tr.customer_id;

/* 7. Transaction summary status must equal its latest history status. */
;WITH latest AS
(
    SELECT transaction_id, canonical_status,
           ROW_NUMBER() OVER
           (
               PARTITION BY transaction_id
               ORDER BY event_timestamp_utc DESC,
                        COALESCE(source_event_sequence, 0) DESC,
                        transaction_status_event_id DESC
           ) AS row_number
    FROM src.transaction_status_history
)
INSERT INTO @audit_results
SELECT 7, N'Transaction current status equals latest history', COUNT_BIG(*), 'ERROR'
FROM src.transactions AS tr
LEFT JOIN latest AS h
    ON h.transaction_id = tr.transaction_id AND h.row_number = 1
WHERE h.transaction_id IS NULL
   OR h.canonical_status <> tr.current_transaction_status;

/* 8. Payment summary status must equal its latest history status. */
;WITH latest AS
(
    SELECT payment_attempt_id, canonical_status,
           ROW_NUMBER() OVER
           (
               PARTITION BY payment_attempt_id
               ORDER BY event_timestamp_utc DESC, payment_status_event_id DESC
           ) AS row_number
    FROM src.payment_status_history
)
INSERT INTO @audit_results
SELECT 8, N'Payment current status equals latest history', COUNT_BIG(*), 'ERROR'
FROM src.payment_attempts AS pa
LEFT JOIN latest AS h
    ON h.payment_attempt_id = pa.payment_attempt_id AND h.row_number = 1
WHERE h.payment_attempt_id IS NULL
   OR h.canonical_status <> pa.current_payment_status;

/* 9. Payout summary status must equal its latest history status. */
;WITH latest AS
(
    SELECT payout_attempt_id, canonical_status,
           ROW_NUMBER() OVER
           (
               PARTITION BY payout_attempt_id
               ORDER BY event_timestamp_utc DESC, payout_status_event_id DESC
           ) AS row_number
    FROM src.payout_status_history
)
INSERT INTO @audit_results
SELECT 9, N'Payout current status equals latest history', COUNT_BIG(*), 'ERROR'
FROM src.payout_attempts AS pa
LEFT JOIN latest AS h
    ON h.payout_attempt_id = pa.payout_attempt_id AND h.row_number = 1
WHERE h.payout_attempt_id IS NULL
   OR h.canonical_status <> pa.current_payout_status;

/* 10. Refund summary status must equal its latest history status. */
;WITH latest AS
(
    SELECT refund_id, refund_status,
           ROW_NUMBER() OVER
           (
               PARTITION BY refund_id
               ORDER BY event_timestamp_utc DESC, refund_status_event_id DESC
           ) AS row_number
    FROM src.refund_status_history
)
INSERT INTO @audit_results
SELECT 10, N'Refund current status equals latest history', COUNT_BIG(*), 'ERROR'
FROM src.refunds AS r
LEFT JOIN latest AS h ON h.refund_id = r.refund_id AND h.row_number = 1
WHERE h.refund_id IS NULL OR h.refund_status <> r.current_refund_status;

/* 11. Document summary status must equal its latest history status. */
;WITH latest AS
(
    SELECT document_id, verification_status,
           ROW_NUMBER() OVER
           (
               PARTITION BY document_id
               ORDER BY event_timestamp_utc DESC,
                        COALESCE(source_event_sequence, 0) DESC,
                        document_verification_event_id DESC
           ) AS row_number
    FROM src.document_verification_history
)
INSERT INTO @audit_results
SELECT 11, N'Document current status equals latest history', COUNT_BIG(*), 'ERROR'
FROM src.customer_documents AS d
LEFT JOIN latest AS h ON h.document_id = d.document_id AND h.row_number = 1
WHERE h.document_id IS NULL
   OR h.verification_status <> d.current_verification_status;

/* 12. Requirement summary status must equal its latest history status. */
;WITH latest AS
(
    SELECT compliance_requirement_id, requirement_status,
           ROW_NUMBER() OVER
           (
               PARTITION BY compliance_requirement_id
               ORDER BY event_timestamp_utc DESC,
                        COALESCE(source_event_sequence, 0) DESC,
                        requirement_event_id DESC
           ) AS row_number
    FROM src.compliance_requirement_history
)
INSERT INTO @audit_results
SELECT 12, N'Requirement current status equals latest history', COUNT_BIG(*), 'ERROR'
FROM src.customer_compliance_requirements AS r
LEFT JOIN latest AS h
    ON h.compliance_requirement_id = r.compliance_requirement_id
   AND h.row_number = 1
WHERE h.compliance_requirement_id IS NULL
   OR h.requirement_status <> r.current_requirement_status;

/* 13. Compliance-review summary must equal its latest history status. */
;WITH latest AS
(
    SELECT compliance_review_id, review_status,
           ROW_NUMBER() OVER
           (
               PARTITION BY compliance_review_id
               ORDER BY event_timestamp_utc DESC,
                        compliance_review_event_id DESC
           ) AS row_number
    FROM src.compliance_review_history
)
INSERT INTO @audit_results
SELECT 13, N'Compliance review current status equals latest history', COUNT_BIG(*), 'ERROR'
FROM src.compliance_reviews AS r
LEFT JOIN latest AS h
    ON h.compliance_review_id = r.compliance_review_id AND h.row_number = 1
WHERE h.compliance_review_id IS NULL
   OR h.review_status <> r.current_review_status;

/* 14. Deposited transactions require a deposited payout and timestamp. */
INSERT INTO @audit_results
SELECT 14, N'Deposited transaction has deposited payout and timestamp', COUNT_BIG(*), 'ERROR'
FROM src.transactions AS tr
LEFT JOIN src.payout_attempts AS pa
    ON pa.transaction_id = tr.transaction_id
   AND pa.current_payout_status = 'Deposited'
WHERE tr.current_transaction_status = 'Deposited'
  AND (tr.deposited_at_utc IS NULL OR pa.payout_attempt_id IS NULL);

/* 15. Non-deposited transactions must not carry a deposited timestamp. */
INSERT INTO @audit_results
SELECT 15, N'Non-deposited transaction has no deposited timestamp', COUNT_BIG(*), 'ERROR'
FROM src.transactions
WHERE current_transaction_status <> 'Deposited'
  AND deposited_at_utc IS NOT NULL;

/* 16. Refunded transactions require a completed refund record. */
INSERT INTO @audit_results
SELECT 16, N'Refunded transaction has completed refund', COUNT_BIG(*), 'ERROR'
FROM src.transactions AS tr
LEFT JOIN src.refunds AS r
    ON r.transaction_id = tr.transaction_id
   AND r.current_refund_status = 'Completed'
WHERE tr.current_transaction_status = 'Refunded'
  AND r.refund_id IS NULL;

/* 17. Prevent the double-loss condition: full refund plus deposit. */
INSERT INTO @audit_results
SELECT 17, N'No transaction is both deposited and fully refunded', COUNT_BIG(*), 'ERROR'
FROM src.transactions AS tr
INNER JOIN src.refunds AS r
    ON r.transaction_id = tr.transaction_id
WHERE tr.current_transaction_status = 'Deposited'
  AND r.refund_type = 'Full'
  AND r.current_refund_status = 'Completed';

/* 18. PaymentException is raised only after more than 24 hours. */
;WITH exception_time AS
(
    SELECT transaction_id, MAX(event_timestamp_utc) AS exception_at_utc
    FROM src.transaction_status_history
    WHERE canonical_status = 'PaymentException'
    GROUP BY transaction_id
)
INSERT INTO @audit_results
SELECT 18, N'Payment exception occurs after 24 hours', COUNT_BIG(*), 'ERROR'
FROM src.transactions AS tr
INNER JOIN src.payment_attempts AS pa ON pa.transaction_id = tr.transaction_id
LEFT JOIN exception_time AS ex ON ex.transaction_id = tr.transaction_id
WHERE tr.current_transaction_status = 'PaymentException'
  AND (ex.exception_at_utc IS NULL
       OR DATEDIFF_BIG(SECOND, pa.submitted_at_utc, ex.exception_at_utc) <= 86400);

/* 19. Threshold transactions create both required evidence requests. */
INSERT INTO @audit_results
SELECT 19, N'Threshold trigger creates PoA and SoF requirements', COUNT_BIG(*), 'ERROR'
FROM
(
    SELECT triggered_transaction_id
    FROM src.customer_compliance_requirements
    WHERE trigger_type = 'CumulativeVolumeThreshold'
    GROUP BY triggered_transaction_id
    HAVING COUNT(DISTINCT requirement_type) <> 2
       OR MIN(threshold_amount_gbp) <> 10000.0000
) AS invalid_threshold_sets;

/* 20. The dataset contains all designed transaction outcome scenarios. */
INSERT INTO @audit_results
SELECT 20, N'All five transaction outcomes are represented',
       5 - COUNT_BIG(DISTINCT current_transaction_status), 'ERROR'
FROM src.transactions
WHERE current_transaction_status IN
      ('ComplianceHold', 'Deposited', 'Failed', 'PaymentException', 'Refunded');

SELECT
    check_number,
    check_name,
    failed_rows,
    CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
    severity
FROM @audit_results
ORDER BY check_number;

SELECT
    current_transaction_status,
    COUNT_BIG(*) AS transaction_count,
    SUM(send_amount_gbp_equivalent) AS gross_volume_gbp
FROM src.transactions
GROUP BY current_transaction_status
ORDER BY current_transaction_status;

SELECT
    COUNT_BIG(DISTINCT CASE WHEN current_transaction_status = 'Deposited'
                            THEN customer_id END) AS active_customers,
    COUNT_BIG(CASE WHEN current_transaction_status = 'Deposited'
                   THEN 1 END) AS deposited_transactions,
    SUM(CASE WHEN current_transaction_status = 'Deposited'
             THEN send_amount_gbp_equivalent ELSE 0 END) AS deposited_volume_gbp,
    AVG(CASE WHEN current_transaction_status = 'Deposited'
             THEN CONVERT(DECIMAL(19, 4),
                  DATEDIFF_BIG(SECOND, initiated_at_utc, deposited_at_utc) / 60.0)
        END) AS average_completion_minutes
FROM src.transactions;

IF EXISTS (SELECT 1 FROM @audit_results WHERE severity = 'ERROR' AND failed_rows <> 0)
BEGIN
    THROW 51000, 'NovaPay synthetic-data audit failed. Review failed_rows above.', 1;
END;

PRINT N'NovaPay synthetic-data audit passed: all error controls returned zero failed rows.';
GO
