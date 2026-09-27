/*
Purpose:
    Create the complete NovaPay operational source schema documented in
    docs/source-data-model.md.

Notes:
    - All timestamps ending in _utc use DATETIME2(3).
    - IDs are BIGINT values supplied by the synthetic-data generator.
    - Status-bearing tables include a fixed process_type_code so their
      statuses can be protected by composite foreign keys to reference data.
    - Circular foreign keys are added after all required tables exist.
*/

USE [NovaPayAnalytics];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ================================================================
   1. Exchange rates: created early because transactions reference it
   ================================================================ */

IF OBJECT_ID(N'src.exchange_rates', N'U') IS NULL
BEGIN
    CREATE TABLE src.exchange_rates
    (
        exchange_rate_id BIGINT NOT NULL,
        base_currency CHAR(3) NOT NULL,
        quote_currency CHAR(3) NOT NULL,
        rate_type VARCHAR(40) NOT NULL,
        rate_value DECIMAL(19, 8) NOT NULL,
        rate_source VARCHAR(100) NOT NULL,
        effective_from_utc DATETIME2(3) NOT NULL,
        effective_to_utc DATETIME2(3) NULL,
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_exchange_rates_created DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_exchange_rates PRIMARY KEY (exchange_rate_id),
        CONSTRAINT UQ_exchange_rates_business_key UNIQUE
            (base_currency, quote_currency, rate_type, rate_source, effective_from_utc),
        CONSTRAINT CK_exchange_rates_positive CHECK (rate_value > 0),
        CONSTRAINT CK_exchange_rates_currencies CHECK (base_currency <> quote_currency),
        CONSTRAINT CK_exchange_rates_period CHECK
            (effective_to_utc IS NULL OR effective_to_utc > effective_from_utc)
    );
    PRINT N'Created table: src.exchange_rates';
END
ELSE PRINT N'Table already exists: src.exchange_rates';
GO

/* ================================================================
   2. Registration attempts and customers
   ================================================================ */

IF OBJECT_ID(N'src.registration_attempts', N'U') IS NULL
BEGIN
    CREATE TABLE src.registration_attempts
    (
        registration_attempt_id BIGINT NOT NULL,
        session_id VARCHAR(100) NOT NULL,
        started_at_utc DATETIME2(3) NOT NULL,
        last_activity_at_utc DATETIME2(3) NOT NULL,
        completed_at_utc DATETIME2(3) NULL,
        last_completed_step VARCHAR(100) NULL,
        process_type_code VARCHAR(50) NOT NULL
            CONSTRAINT DF_registration_attempts_process DEFAULT ('RegistrationAttempt'),
        attempt_status VARCHAR(60) NOT NULL,
        acquisition_channel VARCHAR(60) NULL,
        device_type VARCHAR(40) NULL,
        country_code CHAR(2) NULL,
        customer_id BIGINT NULL,
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_registration_attempts_created DEFAULT (SYSUTCDATETIME()),
        updated_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_registration_attempts_updated DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_registration_attempts PRIMARY KEY (registration_attempt_id),
        CONSTRAINT UQ_registration_attempts_session UNIQUE (session_id),
        CONSTRAINT CK_registration_attempts_process CHECK
            (process_type_code = 'RegistrationAttempt'),
        CONSTRAINT CK_registration_attempts_activity CHECK
            (last_activity_at_utc >= started_at_utc),
        CONSTRAINT CK_registration_attempts_completion_time CHECK
            (completed_at_utc IS NULL OR completed_at_utc >= started_at_utc),
        CONSTRAINT CK_registration_attempts_customer_rule CHECK
            ((attempt_status = 'Completed' AND customer_id IS NOT NULL)
             OR (attempt_status <> 'Completed' AND customer_id IS NULL)),
        CONSTRAINT FK_registration_attempts_status FOREIGN KEY
            (process_type_code, attempt_status)
            REFERENCES ref.process_statuses (process_type_code, status_code)
    );
    PRINT N'Created table: src.registration_attempts';
END
ELSE PRINT N'Table already exists: src.registration_attempts';
GO

IF OBJECT_ID(N'src.customers', N'U') IS NULL
BEGIN
    CREATE TABLE src.customers
    (
        customer_id BIGINT NOT NULL,
        registration_attempt_id BIGINT NOT NULL,
        registration_timestamp_utc DATETIME2(3) NOT NULL,
        first_name NVARCHAR(100) NOT NULL,
        last_name NVARCHAR(100) NOT NULL,
        date_of_birth DATE NOT NULL,
        country_of_residence_code CHAR(2) NOT NULL,
        preferred_currency CHAR(3) NOT NULL,
        process_type_code VARCHAR(50) NOT NULL
            CONSTRAINT DF_customers_process DEFAULT ('CustomerAccount'),
        account_status VARCHAR(60) NOT NULL,
        identity_status VARCHAR(40) NOT NULL,
        transaction_eligibility_status VARCHAR(40) NOT NULL,
        acquisition_channel VARCHAR(60) NULL,
        marketing_consent BIT NOT NULL,
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_customers_created DEFAULT (SYSUTCDATETIME()),
        updated_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_customers_updated DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_customers PRIMARY KEY (customer_id),
        CONSTRAINT UQ_customers_registration_attempt UNIQUE (registration_attempt_id),
        CONSTRAINT CK_customers_process CHECK (process_type_code = 'CustomerAccount'),
        CONSTRAINT CK_customers_identity_status CHECK
            (identity_status IN ('Pending', 'UnderReview', 'Verified', 'Rejected', 'Expired')),
        CONSTRAINT CK_customers_eligibility_status CHECK
            (transaction_eligibility_status IN
                ('NotEligible', 'Eligible', 'RestrictedPendingReview', 'Suspended')),
        CONSTRAINT FK_customers_registration_attempt FOREIGN KEY (registration_attempt_id)
            REFERENCES src.registration_attempts (registration_attempt_id),
        CONSTRAINT FK_customers_account_status FOREIGN KEY
            (process_type_code, account_status)
            REFERENCES ref.process_statuses (process_type_code, status_code)
    );
    PRINT N'Created table: src.customers';
END
ELSE PRINT N'Table already exists: src.customers';
GO

IF OBJECT_ID(N'src.registration_attempt_events', N'U') IS NULL
BEGIN
    CREATE TABLE src.registration_attempt_events
    (
        registration_attempt_event_id BIGINT NOT NULL,
        registration_attempt_id BIGINT NOT NULL,
        event_type VARCHAR(60) NOT NULL,
        step_name VARCHAR(100) NOT NULL,
        step_sequence SMALLINT NOT NULL,
        event_timestamp_utc DATETIME2(3) NOT NULL,
        validation_result VARCHAR(40) NULL,
        error_code VARCHAR(60) NULL,
        source_event_sequence BIGINT NULL,
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_registration_events_created DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_registration_attempt_events PRIMARY KEY
            (registration_attempt_event_id),
        CONSTRAINT CK_registration_events_step CHECK (step_sequence > 0),
        CONSTRAINT FK_registration_events_attempt FOREIGN KEY (registration_attempt_id)
            REFERENCES src.registration_attempts (registration_attempt_id)
    );
    PRINT N'Created table: src.registration_attempt_events';
END
ELSE PRINT N'Table already exists: src.registration_attempt_events';
GO

/* ================================================================
   3. Compliance requirements (transaction FK is added later)
   ================================================================ */

IF OBJECT_ID(N'src.customer_compliance_requirements', N'U') IS NULL
BEGIN
    CREATE TABLE src.customer_compliance_requirements
    (
        compliance_requirement_id BIGINT NOT NULL,
        customer_id BIGINT NOT NULL,
        requirement_type VARCHAR(40) NOT NULL,
        trigger_type VARCHAR(50) NOT NULL,
        triggered_transaction_id BIGINT NULL,
        threshold_amount_gbp DECIMAL(19, 4) NULL,
        qualifying_volume_gbp DECIMAL(19, 4) NULL,
        process_type_code VARCHAR(50) NOT NULL
            CONSTRAINT DF_compliance_requirements_process DEFAULT ('ComplianceRequirement'),
        current_requirement_status VARCHAR(60) NOT NULL,
        triggered_at_utc DATETIME2(3) NOT NULL,
        satisfied_at_utc DATETIME2(3) NULL,
        expires_on DATE NULL,
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_compliance_requirements_created DEFAULT (SYSUTCDATETIME()),
        updated_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_compliance_requirements_updated DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_customer_compliance_requirements PRIMARY KEY
            (compliance_requirement_id),
        CONSTRAINT CK_compliance_requirements_process CHECK
            (process_type_code = 'ComplianceRequirement'),
        CONSTRAINT CK_compliance_requirements_type CHECK
            (requirement_type IN ('ProofOfAddress', 'SourceOfFunds')),
        CONSTRAINT CK_compliance_requirements_trigger CHECK
            (trigger_type IN
                ('CumulativeVolumeThreshold', 'CustomerRisk',
                 'TransactionRisk', 'ManualComplianceRequest')),
        CONSTRAINT CK_compliance_requirements_amounts CHECK
            ((threshold_amount_gbp IS NULL OR threshold_amount_gbp > 0)
             AND (qualifying_volume_gbp IS NULL OR qualifying_volume_gbp >= 0)),
        CONSTRAINT CK_compliance_requirements_satisfied_time CHECK
            (satisfied_at_utc IS NULL OR satisfied_at_utc >= triggered_at_utc),
        CONSTRAINT FK_compliance_requirements_customer FOREIGN KEY (customer_id)
            REFERENCES src.customers (customer_id),
        CONSTRAINT FK_compliance_requirements_status FOREIGN KEY
            (process_type_code, current_requirement_status)
            REFERENCES ref.process_statuses (process_type_code, status_code)
    );
    PRINT N'Created table: src.customer_compliance_requirements';
END
ELSE PRINT N'Table already exists: src.customer_compliance_requirements';
GO

IF OBJECT_ID(N'src.compliance_requirement_history', N'U') IS NULL
BEGIN
    CREATE TABLE src.compliance_requirement_history
    (
        requirement_event_id BIGINT NOT NULL,
        compliance_requirement_id BIGINT NOT NULL,
        process_type_code VARCHAR(50) NOT NULL
            CONSTRAINT DF_compliance_requirement_history_process DEFAULT ('ComplianceRequirement'),
        requirement_status VARCHAR(60) NOT NULL,
        event_timestamp_utc DATETIME2(3) NOT NULL,
        reason_code VARCHAR(60) NULL,
        reviewer_role VARCHAR(80) NULL,
        source_system VARCHAR(100) NOT NULL,
        source_event_sequence BIGINT NULL,
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_compliance_requirement_history_created DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_compliance_requirement_history PRIMARY KEY (requirement_event_id),
        CONSTRAINT CK_compliance_requirement_history_process CHECK
            (process_type_code = 'ComplianceRequirement'),
        CONSTRAINT FK_compliance_requirement_history_parent FOREIGN KEY
            (compliance_requirement_id)
            REFERENCES src.customer_compliance_requirements (compliance_requirement_id),
        CONSTRAINT FK_compliance_requirement_history_status FOREIGN KEY
            (process_type_code, requirement_status)
            REFERENCES ref.process_statuses (process_type_code, status_code)
    );
    PRINT N'Created table: src.compliance_requirement_history';
END
ELSE PRINT N'Table already exists: src.compliance_requirement_history';
GO

/* ================================================================
   4. Documents and document verification
   ================================================================ */

IF OBJECT_ID(N'src.customer_documents', N'U') IS NULL
BEGIN
    CREATE TABLE src.customer_documents
    (
        document_id BIGINT NOT NULL,
        customer_id BIGINT NOT NULL,
        compliance_requirement_id BIGINT NULL,
        document_category VARCHAR(40) NOT NULL,
        document_type VARCHAR(60) NOT NULL,
        issuing_country_code CHAR(2) NULL,
        document_reference_token VARCHAR(150) NULL,
        submitted_at_utc DATETIME2(3) NOT NULL,
        document_issue_date DATE NULL,
        document_expiry_date DATE NULL,
        process_type_code VARCHAR(50) NOT NULL
            CONSTRAINT DF_customer_documents_process DEFAULT ('CustomerDocument'),
        current_verification_status VARCHAR(60) NOT NULL,
        current_status_at_utc DATETIME2(3) NOT NULL,
        is_current_document BIT NOT NULL,
        superseded_by_document_id BIGINT NULL,
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_customer_documents_created DEFAULT (SYSUTCDATETIME()),
        updated_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_customer_documents_updated DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_customer_documents PRIMARY KEY (document_id),
        CONSTRAINT CK_customer_documents_process CHECK
            (process_type_code = 'CustomerDocument'),
        CONSTRAINT CK_customer_documents_category CHECK
            (document_category IN ('Identity', 'ProofOfAddress', 'SourceOfFunds')),
        CONSTRAINT CK_customer_documents_dates CHECK
            (document_expiry_date IS NULL OR document_issue_date IS NULL
             OR document_expiry_date >= document_issue_date),
        CONSTRAINT CK_customer_documents_status_time CHECK
            (current_status_at_utc >= submitted_at_utc),
        CONSTRAINT CK_customer_documents_superseded_by CHECK
            (superseded_by_document_id IS NULL OR superseded_by_document_id <> document_id),
        CONSTRAINT FK_customer_documents_customer FOREIGN KEY (customer_id)
            REFERENCES src.customers (customer_id),
        CONSTRAINT FK_customer_documents_requirement FOREIGN KEY (compliance_requirement_id)
            REFERENCES src.customer_compliance_requirements (compliance_requirement_id),
        CONSTRAINT FK_customer_documents_superseded_by FOREIGN KEY (superseded_by_document_id)
            REFERENCES src.customer_documents (document_id),
        CONSTRAINT FK_customer_documents_status FOREIGN KEY
            (process_type_code, current_verification_status)
            REFERENCES ref.process_statuses (process_type_code, status_code)
    );
    PRINT N'Created table: src.customer_documents';
END
ELSE PRINT N'Table already exists: src.customer_documents';
GO

IF OBJECT_ID(N'src.document_verification_history', N'U') IS NULL
BEGIN
    CREATE TABLE src.document_verification_history
    (
        document_verification_event_id BIGINT NOT NULL,
        document_id BIGINT NOT NULL,
        process_type_code VARCHAR(50) NOT NULL
            CONSTRAINT DF_document_verification_history_process DEFAULT ('CustomerDocument'),
        verification_status VARCHAR(60) NOT NULL,
        event_timestamp_utc DATETIME2(3) NOT NULL,
        review_method VARCHAR(20) NULL,
        reason_code VARCHAR(60) NULL,
        reviewer_role VARCHAR(80) NULL,
        source_system VARCHAR(100) NOT NULL,
        source_event_sequence BIGINT NULL,
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_document_verification_history_created DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_document_verification_history PRIMARY KEY
            (document_verification_event_id),
        CONSTRAINT CK_document_verification_history_process CHECK
            (process_type_code = 'CustomerDocument'),
        CONSTRAINT CK_document_verification_review_method CHECK
            (review_method IS NULL OR review_method IN ('Automated', 'Manual')),
        CONSTRAINT FK_document_verification_history_document FOREIGN KEY (document_id)
            REFERENCES src.customer_documents (document_id),
        CONSTRAINT FK_document_verification_history_status FOREIGN KEY
            (process_type_code, verification_status)
            REFERENCES ref.process_statuses (process_type_code, status_code)
    );
    PRINT N'Created table: src.document_verification_history';
END
ELSE PRINT N'Table already exists: src.document_verification_history';
GO

/* ================================================================
   5. Beneficiaries and referrals
   ================================================================ */

IF OBJECT_ID(N'src.beneficiaries', N'U') IS NULL
BEGIN
    CREATE TABLE src.beneficiaries
    (
        beneficiary_id BIGINT NOT NULL,
        customer_id BIGINT NOT NULL,
        first_name NVARCHAR(100) NOT NULL,
        last_name NVARCHAR(100) NOT NULL,
        destination_country_code CHAR(2) NOT NULL,
        receive_currency CHAR(3) NOT NULL,
        collection_method VARCHAR(30) NOT NULL,
        beneficiary_status VARCHAR(30) NOT NULL,
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_beneficiaries_created DEFAULT (SYSUTCDATETIME()),
        updated_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_beneficiaries_updated DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_beneficiaries PRIMARY KEY (beneficiary_id),
        CONSTRAINT CK_beneficiaries_collection_method CHECK
            (collection_method IN ('Bank', 'MobileWallet', 'Cash')),
        CONSTRAINT FK_beneficiaries_customer FOREIGN KEY (customer_id)
            REFERENCES src.customers (customer_id)
    );
    PRINT N'Created table: src.beneficiaries';
END
ELSE PRINT N'Table already exists: src.beneficiaries';
GO

IF OBJECT_ID(N'src.referrals', N'U') IS NULL
BEGIN
    CREATE TABLE src.referrals
    (
        referral_id BIGINT NOT NULL,
        referrer_customer_id BIGINT NOT NULL,
        referral_code VARCHAR(40) NOT NULL,
        referred_contact_token VARCHAR(150) NULL,
        referred_customer_id BIGINT NULL,
        referral_status VARCHAR(40) NOT NULL,
        invited_at_utc DATETIME2(3) NOT NULL,
        registered_at_utc DATETIME2(3) NULL,
        activated_at_utc DATETIME2(3) NULL,
        reward_status VARCHAR(40) NULL,

        CONSTRAINT PK_referrals PRIMARY KEY (referral_id),
        CONSTRAINT UQ_referrals_code UNIQUE (referral_code),
        CONSTRAINT CK_referrals_customer_difference CHECK
            (referred_customer_id IS NULL OR referred_customer_id <> referrer_customer_id),
        CONSTRAINT CK_referrals_times CHECK
            ((registered_at_utc IS NULL OR registered_at_utc >= invited_at_utc)
             AND (activated_at_utc IS NULL OR
                  (registered_at_utc IS NOT NULL AND activated_at_utc >= registered_at_utc))),
        CONSTRAINT FK_referrals_referrer FOREIGN KEY (referrer_customer_id)
            REFERENCES src.customers (customer_id),
        CONSTRAINT FK_referrals_referred FOREIGN KEY (referred_customer_id)
            REFERENCES src.customers (customer_id)
    );
    PRINT N'Created table: src.referrals';
END
ELSE PRINT N'Table already exists: src.referrals';
GO

/* ================================================================
   6. Transaction attempts (transaction FK is added later)
   ================================================================ */

IF OBJECT_ID(N'src.transaction_attempts', N'U') IS NULL
BEGIN
    CREATE TABLE src.transaction_attempts
    (
        transaction_attempt_id BIGINT NOT NULL,
        customer_id BIGINT NOT NULL,
        started_at_utc DATETIME2(3) NOT NULL,
        last_activity_at_utc DATETIME2(3) NOT NULL,
        last_completed_step VARCHAR(100) NULL,
        send_amount DECIMAL(19, 4) NULL,
        send_currency CHAR(3) NULL,
        destination_country_code CHAR(2) NULL,
        beneficiary_id BIGINT NULL,
        collection_method VARCHAR(30) NULL,
        quoted_exchange_rate_id BIGINT NULL,
        process_type_code VARCHAR(50) NOT NULL
            CONSTRAINT DF_transaction_attempts_process DEFAULT ('TransactionAttempt'),
        attempt_status VARCHAR(60) NOT NULL,
        transaction_id BIGINT NULL,
        submitted_at_utc DATETIME2(3) NULL,
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_transaction_attempts_created DEFAULT (SYSUTCDATETIME()),
        updated_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_transaction_attempts_updated DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_transaction_attempts PRIMARY KEY (transaction_attempt_id),
        CONSTRAINT CK_transaction_attempts_process CHECK
            (process_type_code = 'TransactionAttempt'),
        CONSTRAINT CK_transaction_attempts_activity CHECK
            (last_activity_at_utc >= started_at_utc),
        CONSTRAINT CK_transaction_attempts_amount CHECK
            (send_amount IS NULL OR send_amount > 0),
        CONSTRAINT CK_transaction_attempts_collection_method CHECK
            (collection_method IS NULL OR collection_method IN ('Bank', 'Wallet', 'MobileWallet', 'Cash')),
        CONSTRAINT CK_transaction_attempts_submission CHECK
            ((attempt_status = 'Submitted' AND transaction_id IS NOT NULL
              AND submitted_at_utc IS NOT NULL)
             OR (attempt_status <> 'Submitted' AND transaction_id IS NULL)),
        CONSTRAINT CK_transaction_attempts_submission_time CHECK
            (submitted_at_utc IS NULL OR submitted_at_utc >= started_at_utc),
        CONSTRAINT FK_transaction_attempts_customer FOREIGN KEY (customer_id)
            REFERENCES src.customers (customer_id),
        CONSTRAINT FK_transaction_attempts_beneficiary FOREIGN KEY (beneficiary_id)
            REFERENCES src.beneficiaries (beneficiary_id),
        CONSTRAINT FK_transaction_attempts_rate FOREIGN KEY (quoted_exchange_rate_id)
            REFERENCES src.exchange_rates (exchange_rate_id),
        CONSTRAINT FK_transaction_attempts_status FOREIGN KEY
            (process_type_code, attempt_status)
            REFERENCES ref.process_statuses (process_type_code, status_code)
    );
    PRINT N'Created table: src.transaction_attempts';
END
ELSE PRINT N'Table already exists: src.transaction_attempts';
GO

IF OBJECT_ID(N'src.transaction_attempt_events', N'U') IS NULL
BEGIN
    CREATE TABLE src.transaction_attempt_events
    (
        transaction_attempt_event_id BIGINT NOT NULL,
        transaction_attempt_id BIGINT NOT NULL,
        event_type VARCHAR(60) NOT NULL,
        step_name VARCHAR(100) NOT NULL,
        step_sequence SMALLINT NOT NULL,
        event_timestamp_utc DATETIME2(3) NOT NULL,
        validation_result VARCHAR(40) NULL,
        error_code VARCHAR(60) NULL,
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_transaction_attempt_events_created DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_transaction_attempt_events PRIMARY KEY (transaction_attempt_event_id),
        CONSTRAINT CK_transaction_attempt_events_step CHECK (step_sequence > 0),
        CONSTRAINT FK_transaction_attempt_events_attempt FOREIGN KEY (transaction_attempt_id)
            REFERENCES src.transaction_attempts (transaction_attempt_id)
    );
    PRINT N'Created table: src.transaction_attempt_events';
END
ELSE PRINT N'Table already exists: src.transaction_attempt_events';
GO

/* ================================================================
   7. Transactions
   ================================================================ */

IF OBJECT_ID(N'src.transactions', N'U') IS NULL
BEGIN
    CREATE TABLE src.transactions
    (
        transaction_id BIGINT NOT NULL,
        transaction_attempt_id BIGINT NOT NULL,
        customer_id BIGINT NOT NULL,
        beneficiary_id BIGINT NOT NULL,
        send_amount DECIMAL(19, 4) NOT NULL,
        send_currency CHAR(3) NOT NULL,
        send_amount_gbp_equivalent DECIMAL(19, 4) NOT NULL,
        receive_amount DECIMAL(19, 4) NOT NULL,
        receive_currency CHAR(3) NOT NULL,
        transfer_fee DECIMAL(19, 4) NOT NULL,
        customer_exchange_rate DECIMAL(19, 8) NOT NULL,
        market_exchange_rate_id BIGINT NOT NULL,
        collection_method VARCHAR(30) NOT NULL,
        process_type_code VARCHAR(50) NOT NULL
            CONSTRAINT DF_transactions_process DEFAULT ('Transaction'),
        current_transaction_status VARCHAR(60) NOT NULL,
        initiated_at_utc DATETIME2(3) NOT NULL,
        deposited_at_utc DATETIME2(3) NULL,
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_transactions_created DEFAULT (SYSUTCDATETIME()),
        updated_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_transactions_updated DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_transactions PRIMARY KEY (transaction_id),
        CONSTRAINT UQ_transactions_attempt UNIQUE (transaction_attempt_id),
        CONSTRAINT CK_transactions_process CHECK (process_type_code = 'Transaction'),
        CONSTRAINT CK_transactions_amounts CHECK
            (send_amount > 0 AND send_amount_gbp_equivalent > 0
             AND receive_amount > 0 AND transfer_fee >= 0
             AND customer_exchange_rate > 0),
        CONSTRAINT CK_transactions_collection_method CHECK
            (collection_method IN ('Bank', 'Wallet', 'MobileWallet', 'Cash')),
        CONSTRAINT CK_transactions_deposit_time CHECK
            (deposited_at_utc IS NULL OR deposited_at_utc >= initiated_at_utc),
        CONSTRAINT FK_transactions_attempt FOREIGN KEY (transaction_attempt_id)
            REFERENCES src.transaction_attempts (transaction_attempt_id),
        CONSTRAINT FK_transactions_customer FOREIGN KEY (customer_id)
            REFERENCES src.customers (customer_id),
        CONSTRAINT FK_transactions_beneficiary FOREIGN KEY (beneficiary_id)
            REFERENCES src.beneficiaries (beneficiary_id),
        CONSTRAINT FK_transactions_market_rate FOREIGN KEY (market_exchange_rate_id)
            REFERENCES src.exchange_rates (exchange_rate_id),
        CONSTRAINT FK_transactions_status FOREIGN KEY
            (process_type_code, current_transaction_status)
            REFERENCES ref.process_statuses (process_type_code, status_code)
    );
    PRINT N'Created table: src.transactions';
END
ELSE PRINT N'Table already exists: src.transactions';
GO

IF OBJECT_ID(N'src.transaction_status_history', N'U') IS NULL
BEGIN
    CREATE TABLE src.transaction_status_history
    (
        transaction_status_event_id BIGINT NOT NULL,
        transaction_id BIGINT NOT NULL,
        source_status VARCHAR(100) NOT NULL,
        process_type_code VARCHAR(50) NOT NULL
            CONSTRAINT DF_transaction_history_process DEFAULT ('Transaction'),
        canonical_status VARCHAR(60) NOT NULL,
        event_timestamp_utc DATETIME2(3) NOT NULL,
        reason_code VARCHAR(60) NULL,
        source_system VARCHAR(100) NOT NULL,
        source_event_sequence BIGINT NULL,
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_transaction_history_created DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_transaction_status_history PRIMARY KEY (transaction_status_event_id),
        CONSTRAINT CK_transaction_history_process CHECK
            (process_type_code = 'Transaction'),
        CONSTRAINT FK_transaction_history_transaction FOREIGN KEY (transaction_id)
            REFERENCES src.transactions (transaction_id),
        CONSTRAINT FK_transaction_history_status FOREIGN KEY
            (process_type_code, canonical_status)
            REFERENCES ref.process_statuses (process_type_code, status_code)
    );
    PRINT N'Created table: src.transaction_status_history';
END
ELSE PRINT N'Table already exists: src.transaction_status_history';
GO

/* ================================================================
   8. Funding payments
   ================================================================ */

IF OBJECT_ID(N'src.payment_attempts', N'U') IS NULL
BEGIN
    CREATE TABLE src.payment_attempts
    (
        payment_attempt_id BIGINT NOT NULL,
        transaction_id BIGINT NOT NULL,
        payment_method VARCHAR(40) NOT NULL,
        payment_provider VARCHAR(100) NOT NULL,
        payment_amount DECIMAL(19, 4) NOT NULL,
        payment_currency CHAR(3) NOT NULL,
        provider_reference_token VARCHAR(150) NULL,
        process_type_code VARCHAR(50) NOT NULL
            CONSTRAINT DF_payment_attempts_process DEFAULT ('FundingPayment'),
        current_payment_status VARCHAR(60) NOT NULL,
        submitted_at_utc DATETIME2(3) NOT NULL,
        confirmed_at_utc DATETIME2(3) NULL,
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_payment_attempts_created DEFAULT (SYSUTCDATETIME()),
        updated_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_payment_attempts_updated DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_payment_attempts PRIMARY KEY (payment_attempt_id),
        CONSTRAINT CK_payment_attempts_process CHECK
            (process_type_code = 'FundingPayment'),
        CONSTRAINT CK_payment_attempts_amount CHECK (payment_amount > 0),
        CONSTRAINT CK_payment_attempts_confirmation_time CHECK
            (confirmed_at_utc IS NULL OR confirmed_at_utc >= submitted_at_utc),
        CONSTRAINT FK_payment_attempts_transaction FOREIGN KEY (transaction_id)
            REFERENCES src.transactions (transaction_id),
        CONSTRAINT FK_payment_attempts_status FOREIGN KEY
            (process_type_code, current_payment_status)
            REFERENCES ref.process_statuses (process_type_code, status_code)
    );
    PRINT N'Created table: src.payment_attempts';
END
ELSE PRINT N'Table already exists: src.payment_attempts';
GO

IF OBJECT_ID(N'src.payment_status_history', N'U') IS NULL
BEGIN
    CREATE TABLE src.payment_status_history
    (
        payment_status_event_id BIGINT NOT NULL,
        payment_attempt_id BIGINT NOT NULL,
        source_status VARCHAR(100) NOT NULL,
        process_type_code VARCHAR(50) NOT NULL
            CONSTRAINT DF_payment_history_process DEFAULT ('FundingPayment'),
        canonical_status VARCHAR(60) NOT NULL,
        event_timestamp_utc DATETIME2(3) NOT NULL,
        reason_code VARCHAR(60) NULL,
        source_system VARCHAR(100) NOT NULL,
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_payment_history_created DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_payment_status_history PRIMARY KEY (payment_status_event_id),
        CONSTRAINT CK_payment_history_process CHECK
            (process_type_code = 'FundingPayment'),
        CONSTRAINT FK_payment_history_attempt FOREIGN KEY (payment_attempt_id)
            REFERENCES src.payment_attempts (payment_attempt_id),
        CONSTRAINT FK_payment_history_status FOREIGN KEY
            (process_type_code, canonical_status)
            REFERENCES ref.process_statuses (process_type_code, status_code)
    );
    PRINT N'Created table: src.payment_status_history';
END
ELSE PRINT N'Table already exists: src.payment_status_history';
GO

/* ================================================================
   9. Beneficiary payouts
   ================================================================ */

IF OBJECT_ID(N'src.payout_attempts', N'U') IS NULL
BEGIN
    CREATE TABLE src.payout_attempts
    (
        payout_attempt_id BIGINT NOT NULL,
        transaction_id BIGINT NOT NULL,
        payout_partner VARCHAR(100) NOT NULL,
        collection_method VARCHAR(30) NOT NULL,
        payout_amount DECIMAL(19, 4) NOT NULL,
        payout_currency CHAR(3) NOT NULL,
        partner_reference_token VARCHAR(150) NULL,
        process_type_code VARCHAR(50) NOT NULL
            CONSTRAINT DF_payout_attempts_process DEFAULT ('BeneficiaryPayout'),
        current_payout_status VARCHAR(60) NOT NULL,
        submitted_at_utc DATETIME2(3) NOT NULL,
        completed_at_utc DATETIME2(3) NULL,
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_payout_attempts_created DEFAULT (SYSUTCDATETIME()),
        updated_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_payout_attempts_updated DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_payout_attempts PRIMARY KEY (payout_attempt_id),
        CONSTRAINT CK_payout_attempts_process CHECK
            (process_type_code = 'BeneficiaryPayout'),
        CONSTRAINT CK_payout_attempts_amount CHECK (payout_amount > 0),
        CONSTRAINT CK_payout_attempts_collection_method CHECK
            (collection_method IN ('Bank', 'MobileWallet', 'Cash')),
        CONSTRAINT CK_payout_attempts_completion_time CHECK
            (completed_at_utc IS NULL OR completed_at_utc >= submitted_at_utc),
        CONSTRAINT FK_payout_attempts_transaction FOREIGN KEY (transaction_id)
            REFERENCES src.transactions (transaction_id),
        CONSTRAINT FK_payout_attempts_status FOREIGN KEY
            (process_type_code, current_payout_status)
            REFERENCES ref.process_statuses (process_type_code, status_code)
    );
    PRINT N'Created table: src.payout_attempts';
END
ELSE PRINT N'Table already exists: src.payout_attempts';
GO

IF OBJECT_ID(N'src.payout_status_history', N'U') IS NULL
BEGIN
    CREATE TABLE src.payout_status_history
    (
        payout_status_event_id BIGINT NOT NULL,
        payout_attempt_id BIGINT NOT NULL,
        source_status VARCHAR(100) NOT NULL,
        process_type_code VARCHAR(50) NOT NULL
            CONSTRAINT DF_payout_history_process DEFAULT ('BeneficiaryPayout'),
        canonical_status VARCHAR(60) NOT NULL,
        event_timestamp_utc DATETIME2(3) NOT NULL,
        reason_code VARCHAR(60) NULL,
        source_system VARCHAR(100) NOT NULL,
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_payout_history_created DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_payout_status_history PRIMARY KEY (payout_status_event_id),
        CONSTRAINT CK_payout_history_process CHECK
            (process_type_code = 'BeneficiaryPayout'),
        CONSTRAINT FK_payout_history_attempt FOREIGN KEY (payout_attempt_id)
            REFERENCES src.payout_attempts (payout_attempt_id),
        CONSTRAINT FK_payout_history_status FOREIGN KEY
            (process_type_code, canonical_status)
            REFERENCES ref.process_statuses (process_type_code, status_code)
    );
    PRINT N'Created table: src.payout_status_history';
END
ELSE PRINT N'Table already exists: src.payout_status_history';
GO

/* ================================================================
   10. Refunds
   ================================================================ */

IF OBJECT_ID(N'src.refunds', N'U') IS NULL
BEGIN
    CREATE TABLE src.refunds
    (
        refund_id BIGINT NOT NULL,
        transaction_id BIGINT NOT NULL,
        payment_attempt_id BIGINT NOT NULL,
        refund_type VARCHAR(20) NOT NULL,
        refund_amount DECIMAL(19, 4) NOT NULL,
        refund_currency CHAR(3) NOT NULL,
        refund_reason_code VARCHAR(60) NOT NULL,
        process_type_code VARCHAR(50) NOT NULL
            CONSTRAINT DF_refunds_process DEFAULT ('Refund'),
        current_refund_status VARCHAR(60) NOT NULL,
        requested_at_utc DATETIME2(3) NOT NULL,
        completed_at_utc DATETIME2(3) NULL,
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_refunds_created DEFAULT (SYSUTCDATETIME()),
        updated_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_refunds_updated DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_refunds PRIMARY KEY (refund_id),
        CONSTRAINT CK_refunds_process CHECK (process_type_code = 'Refund'),
        CONSTRAINT CK_refunds_type CHECK (refund_type IN ('Full', 'Partial')),
        CONSTRAINT CK_refunds_amount CHECK (refund_amount > 0),
        CONSTRAINT CK_refunds_completion_time CHECK
            (completed_at_utc IS NULL OR completed_at_utc >= requested_at_utc),
        CONSTRAINT FK_refunds_transaction FOREIGN KEY (transaction_id)
            REFERENCES src.transactions (transaction_id),
        CONSTRAINT FK_refunds_payment FOREIGN KEY (payment_attempt_id)
            REFERENCES src.payment_attempts (payment_attempt_id),
        CONSTRAINT FK_refunds_status FOREIGN KEY
            (process_type_code, current_refund_status)
            REFERENCES ref.process_statuses (process_type_code, status_code)
    );
    PRINT N'Created table: src.refunds';
END
ELSE PRINT N'Table already exists: src.refunds';
GO

IF OBJECT_ID(N'src.refund_status_history', N'U') IS NULL
BEGIN
    CREATE TABLE src.refund_status_history
    (
        refund_status_event_id BIGINT NOT NULL,
        refund_id BIGINT NOT NULL,
        process_type_code VARCHAR(50) NOT NULL
            CONSTRAINT DF_refund_history_process DEFAULT ('Refund'),
        refund_status VARCHAR(60) NOT NULL,
        event_timestamp_utc DATETIME2(3) NOT NULL,
        reason_code VARCHAR(60) NULL,
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_refund_history_created DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_refund_status_history PRIMARY KEY (refund_status_event_id),
        CONSTRAINT CK_refund_history_process CHECK (process_type_code = 'Refund'),
        CONSTRAINT FK_refund_history_refund FOREIGN KEY (refund_id)
            REFERENCES src.refunds (refund_id),
        CONSTRAINT FK_refund_history_status FOREIGN KEY
            (process_type_code, refund_status)
            REFERENCES ref.process_statuses (process_type_code, status_code)
    );
    PRINT N'Created table: src.refund_status_history';
END
ELSE PRINT N'Table already exists: src.refund_status_history';
GO

/* ================================================================
   11. Compliance reviews
   ================================================================ */

IF OBJECT_ID(N'src.compliance_reviews', N'U') IS NULL
BEGIN
    CREATE TABLE src.compliance_reviews
    (
        compliance_review_id BIGINT NOT NULL,
        customer_id BIGINT NOT NULL,
        transaction_id BIGINT NULL,
        review_type VARCHAR(40) NOT NULL,
        trigger_rule_code VARCHAR(60) NOT NULL,
        risk_level VARCHAR(20) NOT NULL,
        process_type_code VARCHAR(50) NOT NULL
            CONSTRAINT DF_compliance_reviews_process DEFAULT ('ComplianceReview'),
        current_review_status VARCHAR(60) NOT NULL,
        review_outcome VARCHAR(60) NULL,
        opened_at_utc DATETIME2(3) NOT NULL,
        closed_at_utc DATETIME2(3) NULL,
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_compliance_reviews_created DEFAULT (SYSUTCDATETIME()),
        updated_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_compliance_reviews_updated DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_compliance_reviews PRIMARY KEY (compliance_review_id),
        CONSTRAINT CK_compliance_reviews_process CHECK
            (process_type_code = 'ComplianceReview'),
        CONSTRAINT CK_compliance_reviews_type CHECK
            (review_type IN ('Customer', 'Transaction', 'Sanctions', 'Document', 'Other')),
        CONSTRAINT CK_compliance_reviews_risk CHECK
            (risk_level IN ('Low', 'Medium', 'High')),
        CONSTRAINT CK_compliance_reviews_close_time CHECK
            (closed_at_utc IS NULL OR closed_at_utc >= opened_at_utc),
        CONSTRAINT FK_compliance_reviews_customer FOREIGN KEY (customer_id)
            REFERENCES src.customers (customer_id),
        CONSTRAINT FK_compliance_reviews_transaction FOREIGN KEY (transaction_id)
            REFERENCES src.transactions (transaction_id),
        CONSTRAINT FK_compliance_reviews_status FOREIGN KEY
            (process_type_code, current_review_status)
            REFERENCES ref.process_statuses (process_type_code, status_code)
    );
    PRINT N'Created table: src.compliance_reviews';
END
ELSE PRINT N'Table already exists: src.compliance_reviews';
GO

IF OBJECT_ID(N'src.compliance_review_history', N'U') IS NULL
BEGIN
    CREATE TABLE src.compliance_review_history
    (
        compliance_review_event_id BIGINT NOT NULL,
        compliance_review_id BIGINT NOT NULL,
        process_type_code VARCHAR(50) NOT NULL
            CONSTRAINT DF_compliance_review_history_process DEFAULT ('ComplianceReview'),
        review_status VARCHAR(60) NOT NULL,
        event_timestamp_utc DATETIME2(3) NOT NULL,
        reason_code VARCHAR(60) NULL,
        reviewer_role VARCHAR(80) NULL,
        created_at_utc DATETIME2(3) NOT NULL
            CONSTRAINT DF_compliance_review_history_created DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_compliance_review_history PRIMARY KEY (compliance_review_event_id),
        CONSTRAINT CK_compliance_review_history_process CHECK
            (process_type_code = 'ComplianceReview'),
        CONSTRAINT FK_compliance_review_history_parent FOREIGN KEY (compliance_review_id)
            REFERENCES src.compliance_reviews (compliance_review_id),
        CONSTRAINT FK_compliance_review_history_status FOREIGN KEY
            (process_type_code, review_status)
            REFERENCES ref.process_statuses (process_type_code, status_code)
    );
    PRINT N'Created table: src.compliance_review_history';
END
ELSE PRINT N'Table already exists: src.compliance_review_history';
GO

/* ================================================================
   12. Circular foreign keys added after both sides exist
   ================================================================ */

IF NOT EXISTS
(
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_registration_attempts_customer'
      AND parent_object_id = OBJECT_ID(N'src.registration_attempts')
)
BEGIN
    ALTER TABLE src.registration_attempts WITH CHECK
    ADD CONSTRAINT FK_registration_attempts_customer
        FOREIGN KEY (customer_id) REFERENCES src.customers (customer_id);
    PRINT N'Created foreign key: FK_registration_attempts_customer';
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_transaction_attempts_transaction'
      AND parent_object_id = OBJECT_ID(N'src.transaction_attempts')
)
BEGIN
    ALTER TABLE src.transaction_attempts WITH CHECK
    ADD CONSTRAINT FK_transaction_attempts_transaction
        FOREIGN KEY (transaction_id) REFERENCES src.transactions (transaction_id);
    PRINT N'Created foreign key: FK_transaction_attempts_transaction';
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.foreign_keys
    WHERE name = N'FK_compliance_requirements_transaction'
      AND parent_object_id = OBJECT_ID(N'src.customer_compliance_requirements')
)
BEGIN
    ALTER TABLE src.customer_compliance_requirements WITH CHECK
    ADD CONSTRAINT FK_compliance_requirements_transaction
        FOREIGN KEY (triggered_transaction_id) REFERENCES src.transactions (transaction_id);
    PRINT N'Created foreign key: FK_compliance_requirements_transaction';
END;
GO

/* ================================================================
   13. Filtered uniqueness and event-ordering indexes
   ================================================================ */

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'src.registration_attempts') AND name = N'UX_registration_attempts_customer')
    CREATE UNIQUE INDEX UX_registration_attempts_customer
        ON src.registration_attempts (customer_id) WHERE customer_id IS NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'src.transaction_attempts') AND name = N'UX_transaction_attempts_transaction')
    CREATE UNIQUE INDEX UX_transaction_attempts_transaction
        ON src.transaction_attempts (transaction_id) WHERE transaction_id IS NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'src.referrals') AND name = N'UX_referrals_referred_customer')
    CREATE UNIQUE INDEX UX_referrals_referred_customer
        ON src.referrals (referred_customer_id) WHERE referred_customer_id IS NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'src.customer_documents') AND name = N'UX_customer_documents_reference')
    CREATE UNIQUE INDEX UX_customer_documents_reference
        ON src.customer_documents (document_reference_token)
        WHERE document_reference_token IS NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'src.payment_attempts') AND name = N'UX_payment_attempts_provider_reference')
    CREATE UNIQUE INDEX UX_payment_attempts_provider_reference
        ON src.payment_attempts (provider_reference_token)
        WHERE provider_reference_token IS NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'src.payout_attempts') AND name = N'UX_payout_attempts_partner_reference')
    CREATE UNIQUE INDEX UX_payout_attempts_partner_reference
        ON src.payout_attempts (partner_reference_token)
        WHERE partner_reference_token IS NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'src.registration_attempt_events') AND name = N'IX_registration_events_timeline')
    CREATE INDEX IX_registration_events_timeline
        ON src.registration_attempt_events
        (registration_attempt_id, event_timestamp_utc, source_event_sequence);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'src.transaction_status_history') AND name = N'IX_transaction_history_timeline')
    CREATE INDEX IX_transaction_history_timeline
        ON src.transaction_status_history
        (transaction_id, event_timestamp_utc, source_event_sequence);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'src.payment_status_history') AND name = N'IX_payment_history_timeline')
    CREATE INDEX IX_payment_history_timeline
        ON src.payment_status_history (payment_attempt_id, event_timestamp_utc);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'src.payout_status_history') AND name = N'IX_payout_history_timeline')
    CREATE INDEX IX_payout_history_timeline
        ON src.payout_status_history (payout_attempt_id, event_timestamp_utc);
GO

/* ================================================================
   14. Deployment verification
   ================================================================ */

DECLARE @expected_tables TABLE (table_name SYSNAME PRIMARY KEY);

INSERT INTO @expected_tables (table_name)
VALUES
('registration_attempts'),
('registration_attempt_events'),
('customers'),
('customer_documents'),
('document_verification_history'),
('customer_compliance_requirements'),
('compliance_requirement_history'),
('beneficiaries'),
('referrals'),
('transaction_attempts'),
('transaction_attempt_events'),
('transactions'),
('transaction_status_history'),
('payment_attempts'),
('payment_status_history'),
('payout_attempts'),
('payout_status_history'),
('refunds'),
('refund_status_history'),
('exchange_rates'),
('compliance_reviews'),
('compliance_review_history');

IF EXISTS
(
    SELECT 1
    FROM @expected_tables AS expected
    WHERE OBJECT_ID(N'src.' + expected.table_name, N'U') IS NULL
)
BEGIN
    THROW 50010, 'One or more expected source tables were not created.', 1;
END;

SELECT
    s.name AS schema_name,
    t.name AS table_name,
    COUNT(c.column_id) AS column_count
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON t.schema_id = s.schema_id
INNER JOIN sys.columns AS c
    ON t.object_id = c.object_id
WHERE s.name = N'src'
  AND t.name IN (SELECT table_name FROM @expected_tables)
GROUP BY s.name, t.name
ORDER BY t.name;

SELECT
    COUNT(*) AS source_table_count
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON t.schema_id = s.schema_id
WHERE s.name = N'src'
  AND t.name IN (SELECT table_name FROM @expected_tables);
GO
