# NovaPay Source Data Model

## 1. Purpose

This document defines the proposed source entities, grain, identifiers, important attributes and relationships for the NovaPay Remittance Analytics Platform.

The model separates customer journeys, submitted transactions, funding payments, beneficiary payouts, compliance requirements and their event histories. This separation allows NovaPay to distinguish customer abandonment from payment-system, compliance, internal-processing and payout-partner delays.

All records and examples in this portfolio will be synthetic. No real customer, employer, card, bank, payment-provider or compliance data will be used.

### 1.1 Confirmed market scope

The first version will use the following sending markets and currencies:

| Sending country | Currency |
| --- | --- |
| United Kingdom | GBP |
| Ireland | EUR |
| France | EUR |
| Germany | EUR |
| Spain | EUR |
| Australia | AUD |

The five destination countries are Nigeria, Ghana, Zambia, Cameroon and Zimbabwe. The associated synthetic payout currencies will be NGN, GHS, ZMW, XAF and USD respectively. Using USD for the Zimbabwe corridor is a documented project assumption rather than a statement that every real remittance provider uses the same payout currency.

## 2. Modelling principles

1. Every table must have a clearly defined grain.
2. Every row must have a unique, non-null and stable primary key.
3. Foreign keys must identify relationships between entities.
4. Original source values must be preserved before analytical standardisation.
5. Current-state records must not replace event histories.
6. Registration attempts, transaction attempts and completed business records must be modelled separately.
7. Remittance instructions, funding payments and beneficiary payouts must be modelled separately.
8. Different currencies must not be aggregated without conversion to a documented common currency.
9. Sensitive values must be minimised, tokenised or excluded when they are not required for analysis.
10. Invalid or late-arriving records must be retained for investigation rather than silently deleted.
11. Compliance requirements must be driven by documented rules and events.
12. All synthetic-data generation rules and assumptions must be documented.

## 3. Date-and-time standard

Every event will contain a complete date and time. Time-only values will not be used for sequencing or duration calculations.

Source timestamps that contain time-zone offsets will be preserved using SQL Server `DATETIMEOFFSET(3)` where appropriate. Standardised analytical timestamps will be converted to Coordinated Universal Time (UTC) and stored using `DATETIME2(3)`.

Standardised timestamp fields will include the `_utc` suffix:

- `event_timestamp_utc`;
- `created_at_utc`;
- `updated_at_utc`;
- `started_at_utc`;
- `submitted_at_utc`;
- `completed_at_utc`.

Example:

```text
verification_status = Approved
event_timestamp_utc = 2026-08-28 09:15:37.420
```

Calendar-only values, such as a document expiry date or date of birth, will use SQL Server `DATE` rather than a timestamp.

## 4. Source-status preservation

NovaPay will preserve the status supplied by each operational system in `source_status`. A separate `canonical_status` will map ambiguous or inconsistent source values to a controlled analytical definition.

For example, a source system may label two different conditions as `Incomplete`. The analytical model will distinguish:

- `IncompleteDraft`: the customer began the transfer journey but did not submit it;
- `PaymentConfirmationPending`: the transaction was submitted and a reference was created, but payment confirmation has not arrived from the card acquirer.

The source value will never be overwritten by the canonical value.

## 5. Entity inventory

| Entity | Grain | Primary key |
| --- | --- | --- |
| `registration_attempts` | One row per registration journey started | `registration_attempt_id` |
| `registration_attempt_events` | One row per event during a registration attempt | `registration_attempt_event_id` |
| `customers` | One row per successfully created customer account | `customer_id` |
| `customer_documents` | One row per customer-document submission or version | `document_id` |
| `document_verification_history` | One row per verification-status event for a document | `document_verification_event_id` |
| `customer_compliance_requirements` | One row per compliance requirement triggered for a customer | `compliance_requirement_id` |
| `compliance_requirement_history` | One row per status event for a compliance requirement | `requirement_event_id` |
| `beneficiaries` | One row per beneficiary | `beneficiary_id` |
| `referrals` | One row per referral invitation | `referral_id` |
| `transaction_attempts` | One row per transfer journey started | `transaction_attempt_id` |
| `transaction_attempt_events` | One row per event during a transaction attempt | `transaction_attempt_event_id` |
| `transactions` | One row per submitted remittance instruction | `transaction_id` |
| `transaction_status_history` | One row per transaction-status event | `transaction_status_event_id` |
| `payment_attempts` | One row per attempt to fund a submitted transaction | `payment_attempt_id` |
| `payment_status_history` | One row per funding-payment status event | `payment_status_event_id` |
| `payout_attempts` | One row per attempt to deliver funds to a beneficiary | `payout_attempt_id` |
| `payout_status_history` | One row per beneficiary-payout status event | `payout_status_event_id` |
| `refunds` | One row per refund instruction | `refund_id` |
| `refund_status_history` | One row per refund-status event | `refund_status_event_id` |
| `exchange_rates` | One row per currency pair, rate type, source and effective timestamp | `exchange_rate_id` |
| `compliance_reviews` | One row per compliance review opened against a customer or transaction | `compliance_review_id` |
| `compliance_review_history` | One row per compliance-review status event | `compliance_review_event_id` |

## 6. Core relationships

| Parent | Child | Relationship |
| --- | --- | --- |
| `registration_attempts` | `registration_attempt_events` | One registration attempt may have many journey events |
| `registration_attempts` | `customers` | One completed registration attempt may create one customer |
| `customers` | `customer_documents` | One customer may submit many documents |
| `customer_documents` | `document_verification_history` | One document may have many verification events |
| `customers` | `customer_compliance_requirements` | One customer may have many compliance requirements |
| `customer_compliance_requirements` | `compliance_requirement_history` | One requirement may have many status events |
| `customer_compliance_requirements` | `customer_documents` | One requirement may be supported by many document submissions |
| `customers` | `beneficiaries` | One customer may maintain many separate beneficiary profiles |
| `customers` | `referrals` | One customer may send many referral invitations |
| `customers` | `transaction_attempts` | One customer may start many transaction attempts |
| `transaction_attempts` | `transaction_attempt_events` | One transaction attempt may have many journey events |
| `transaction_attempts` | `transactions` | One submitted attempt may create one transaction |
| `customers` | `transactions` | One customer may submit many transactions |
| `beneficiaries` | `transactions` | One beneficiary may receive many transactions |
| `transactions` | `transaction_status_history` | One transaction may have many status events |
| `transactions` | `payment_attempts` | One transaction may have many funding-payment attempts |
| `payment_attempts` | `payment_status_history` | One payment attempt may have many status events |
| `transactions` | `payout_attempts` | One transaction may have many beneficiary-payout attempts |
| `payout_attempts` | `payout_status_history` | One payout attempt may have many status events |
| `transactions` | `refunds` | One transaction may have zero or many refund instructions |
| `payment_attempts` | `refunds` | One confirmed payment attempt may have zero or many refunds |
| `refunds` | `refund_status_history` | One refund may have many status events |
| `transactions` | `compliance_reviews` | One transaction may have zero or many compliance reviews |
| `customers` | `compliance_reviews` | One customer may have zero or many compliance reviews |
| `compliance_reviews` | `compliance_review_history` | One review may have many status events |

## 7. Registration and customer tables

### 7.1 `registration_attempts`

**Grain:** One row represents one registration journey started by a prospective customer.

| Column | Description | Required? |
| --- | --- | --- |
| `registration_attempt_id` | Unique attempt identifier | Yes |
| `session_id` | Application-session identifier | Yes |
| `started_at_utc` | Complete UTC timestamp when registration began | Yes |
| `last_activity_at_utc` | Complete UTC timestamp of most recent activity | Yes |
| `completed_at_utc` | Complete UTC timestamp when account creation completed | No |
| `last_completed_step` | Most advanced completed registration step | No |
| `attempt_status` | Current or final attempt status | Yes |
| `acquisition_channel` | Channel that brought the prospect to NovaPay | No |
| `device_type` | Broad device category | No |
| `country_code` | Sending-market country associated with the attempt | No |
| `customer_id` | Customer created by the completed attempt | No |
| `created_at_utc` | Complete UTC timestamp when the row was created | Yes |
| `updated_at_utc` | Complete UTC timestamp when the row was updated | Yes |

**Allowed statuses:** `InProgress`, `Abandoned`, `Resumed`, `Completed`, `Failed`.

**Rules:**

- `customer_id` remains null unless the attempt creates a customer successfully.
- Abandonment is inferred after a documented inactivity threshold.
- Resuming the same saved journey retains the attempt ID; starting again creates a new one.

### 7.2 `registration_attempt_events`

**Grain:** One row represents one event during one registration attempt at one UTC timestamp.

| Column | Description | Required? |
| --- | --- | --- |
| `registration_attempt_event_id` | Unique event identifier | Yes |
| `registration_attempt_id` | Related registration attempt | Yes |
| `event_type` | Event recorded | Yes |
| `step_name` | Registration step associated with the event | Yes |
| `step_sequence` | Numerical order of the step | Yes |
| `event_timestamp_utc` | Complete UTC timestamp when the event occurred | Yes |
| `validation_result` | Validation outcome where applicable | No |
| `error_code` | Non-sensitive failure code | No |
| `source_event_sequence` | Ordering value supplied by the source | No |
| `created_at_utc` | Complete UTC timestamp when the event entered the source | Yes |

**Example events:** `AttemptStarted`, `StepViewed`, `StepCompleted`, `ValidationFailed`, `AttemptAbandoned`, `AttemptResumed`, `RegistrationSubmitted`, `AccountCreated`.

Sensitive values such as names, dates of birth, passwords and document numbers will not be repeated in analytical event records.

### 7.3 `customers`

**Grain:** One row represents one successfully created NovaPay customer account.

| Column | Description | Required? |
| --- | --- | --- |
| `customer_id` | Unique customer identifier | Yes |
| `registration_attempt_id` | Attempt that created the account | Yes |
| `registration_timestamp_utc` | Complete UTC timestamp of account creation | Yes |
| `first_name` | Synthetic first name | Yes |
| `last_name` | Synthetic surname | Yes |
| `date_of_birth` | Synthetic date of birth | Yes |
| `country_of_residence_code` | Customer's country of residence | Yes |
| `preferred_currency` | Preferred sending currency | Yes |
| `account_status` | Current account condition | Yes |
| `identity_status` | Current identity-verification summary | Yes |
| `transaction_eligibility_status` | Whether the customer is eligible to transact | Yes |
| `acquisition_channel` | Registration acquisition channel | No |
| `marketing_consent` | Whether marketing consent was provided | Yes |
| `created_at_utc` | Complete UTC timestamp when the row was created | Yes |
| `updated_at_utc` | Complete UTC timestamp when the row was updated | Yes |

**Allowed account statuses:** `PendingVerification`, `Active`, `Restricted`, `Suspended`, `Closed`.

**Allowed identity statuses:** `Pending`, `UnderReview`, `Verified`, `Rejected`, `Expired`.

**Allowed eligibility statuses:** `NotEligible`, `Eligible`, `RestrictedPendingReview`, `Suspended`.

Exact personal information will not be displayed in public reports. Reporting will use synthetic IDs, age bands and appropriately aggregated geography.

## 8. Document and verification tables

### 8.1 Why documents are generalised

Identity evidence is required during initial verification. Proof of address and source-of-funds evidence are conditional requirements triggered by NovaPay's fictional £10,000 rule or another compliance decision.

A general `customer_documents` table supports all categories without incorrectly describing proof of address or source-of-funds evidence as identity documents.

### 8.2 `customer_documents`

**Grain:** One row represents one document submission or document version supplied by one customer.

| Column | Description | Required? |
| --- | --- | --- |
| `document_id` | Unique document-submission identifier | Yes |
| `customer_id` | Customer who supplied the document | Yes |
| `compliance_requirement_id` | Requirement the document supports | No |
| `document_category` | Business purpose of the document | Yes |
| `document_type` | Specific document type | Yes |
| `issuing_country_code` | Issuing country where applicable | No |
| `document_reference_token` | Synthetic or tokenised reference | No |
| `submitted_at_utc` | Complete UTC timestamp of submission | Yes |
| `document_issue_date` | Document issue date | No |
| `document_expiry_date` | Document expiry date | No |
| `current_verification_status` | Latest known document status | Yes |
| `current_status_at_utc` | Complete UTC timestamp when latest status began | Yes |
| `is_current_document` | Whether this is the current document of its category/type | Yes |
| `superseded_by_document_id` | Newer document replacing this record | No |
| `created_at_utc` | Complete UTC timestamp when the row was created | Yes |
| `updated_at_utc` | Complete UTC timestamp when the row was updated | Yes |

**Document categories:** `Identity`, `ProofOfAddress`, `SourceOfFunds`.

**Example document types:**

- Identity: `Passport`, `DrivingLicence`, `NationalIdentityCard`, `ResidencePermit`;
- Proof of address: `BankStatement`, `UtilityBill`, `CouncilTaxStatement`;
- Source of funds: `Payslip`, `BankStatement`, `SaleAgreement`, `InheritanceEvidence`, `BusinessIncomeEvidence`.

**Allowed statuses:** `Submitted`, `AutomatedReview`, `ManualReview`, `AdditionalInformationRequired`, `Approved`, `Rejected`, `Expired`, `Superseded`.

**Rules:**

- A customer can submit several documents.
- A replacement receives a new `document_id`.
- Rejected documents are retained according to an approved retention schedule rather than overwritten.
- Approved but expired documents do not satisfy a current requirement.
- Raw document images and real document numbers will never enter the public repository.

### 8.3 `document_verification_history`

**Grain:** One row represents one verification-status event for one document at one UTC timestamp.

| Column | Description | Required? |
| --- | --- | --- |
| `document_verification_event_id` | Unique event identifier | Yes |
| `document_id` | Related document | Yes |
| `verification_status` | Status entered by the document | Yes |
| `event_timestamp_utc` | Complete UTC timestamp when the event occurred | Yes |
| `review_method` | `Automated` or `Manual` | No |
| `reason_code` | Non-sensitive decision/delay reason | No |
| `reviewer_role` | Fictional role responsible for manual action | No |
| `source_system` | System that produced the event | Yes |
| `source_event_sequence` | Source ordering value | No |
| `created_at_utc` | Complete UTC timestamp when the event entered the source | Yes |

The latest valid history status must match `customer_documents.current_verification_status`. Events must be retained even when later statuses change.

## 9. Threshold-triggered compliance requirements

### 9.1 Fictional £10,000 policy rule

Proof of address and source-of-funds evidence are not required from every NovaPay customer during initial registration. A customer who completes identity verification may transact until their qualifying volume reaches NovaPay's fictional £10,000 compliance threshold.

The threshold test is:

```text
Previous qualifying deposited volume
+ GBP-equivalent value of the current submitted transaction
>= £10,000
```

When true:

1. create a `ProofOfAddress` requirement;
2. create a `SourceOfFunds` requirement;
3. place the triggering transaction in `ComplianceHold`;
4. request the required evidence;
5. allow the transaction to proceed only after the applicable requirements are satisfied.

EUR transactions will be converted using the documented historical EUR/GBP rate applicable to the transaction. The £10,000 rule is a fictional NovaPay portfolio assumption, not a universal legal threshold.

Qualifying volume is measured over a rolling 12-month window. It includes prior eligible deposited GBP-equivalent volume plus the GBP-equivalent value of the current submitted transaction. When the threshold is triggered, the requirements remain active even if the triggering transaction later fails or is cancelled. They remain active until satisfied or explicitly withdrawn by Compliance.

### 9.2 `customer_compliance_requirements`

**Grain:** One row represents one compliance requirement triggered for one customer.

| Column | Description | Required? |
| --- | --- | --- |
| `compliance_requirement_id` | Unique requirement identifier | Yes |
| `customer_id` | Customer subject to the requirement | Yes |
| `requirement_type` | Evidence or action required | Yes |
| `trigger_type` | Rule/event creating the requirement | Yes |
| `triggered_transaction_id` | Transaction that caused the requirement | No |
| `threshold_amount_gbp` | Applicable policy threshold | No |
| `qualifying_volume_gbp` | Calculated volume when triggered | No |
| `current_requirement_status` | Latest requirement status | Yes |
| `triggered_at_utc` | Complete UTC timestamp when created | Yes |
| `satisfied_at_utc` | Complete UTC timestamp when satisfied | No |
| `expires_on` | Calendar date when approved evidence expires | No |
| `created_at_utc` | Complete UTC timestamp when the row was created | Yes |
| `updated_at_utc` | Complete UTC timestamp when the row was updated | Yes |

**Requirement types:** `ProofOfAddress`, `SourceOfFunds`.

**Trigger types:** `CumulativeVolumeThreshold`, `CustomerRisk`, `TransactionRisk`, `ManualComplianceRequest`.

**Requirement statuses:** `Required`, `AwaitingDocument`, `Submitted`, `UnderReview`, `AdditionalInformationRequired`, `Approved`, `Rejected`, `Expired`, `Waived`, `Withdrawn`.

No physical row is required for `NotRequired`; that state is inferred when no applicable active requirement exists.

### 9.3 `compliance_requirement_history`

**Grain:** One row represents one status event for one customer compliance requirement at one UTC timestamp.

| Column | Description | Required? |
| --- | --- | --- |
| `requirement_event_id` | Unique event identifier | Yes |
| `compliance_requirement_id` | Related compliance requirement | Yes |
| `requirement_status` | Status entered | Yes |
| `event_timestamp_utc` | Complete UTC timestamp of the event | Yes |
| `reason_code` | Non-sensitive reason | No |
| `reviewer_role` | Fictional reviewer role | No |
| `source_system` | System producing the event | Yes |
| `source_event_sequence` | Source ordering value | No |
| `created_at_utc` | Complete UTC timestamp when received | Yes |

The latest valid history status must match the requirement summary table.

## 10. Beneficiary and referral tables

### 10.1 `beneficiaries`

**Grain:** One row represents one beneficiary profile.

| Column | Description | Required? |
| --- | --- | --- |
| `beneficiary_id` | Unique beneficiary identifier | Yes |
| `customer_id` | Customer who owns the saved beneficiary profile | Yes |
| `first_name` | Synthetic first name | Yes |
| `last_name` | Synthetic surname | Yes |
| `destination_country_code` | Beneficiary country | Yes |
| `receive_currency` | Expected receiving currency | Yes |
| `collection_method` | Bank, mobile wallet or cash | Yes |
| `beneficiary_status` | Current profile status | Yes |
| `created_at_utc` | Complete UTC timestamp of creation | Yes |
| `updated_at_utc` | Complete UTC timestamp of update | Yes |

Detailed bank-account or mobile-wallet identifiers will be synthetic and tokenised or omitted from public analytics.

Each beneficiary profile belongs to exactly one customer. If two customers send to the same real-world recipient, each customer retains a separate beneficiary profile with a different `beneficiary_id`.

### 10.2 `referrals`

**Grain:** One row represents one referral invitation created by one customer.

| Column | Description | Required? |
| --- | --- | --- |
| `referral_id` | Unique referral identifier | Yes |
| `referrer_customer_id` | Customer sending the referral | Yes |
| `referral_code` | Synthetic referral code | Yes |
| `referred_contact_token` | Tokenised prospect contact | No |
| `referred_customer_id` | Customer created from the referral | No |
| `referral_status` | Current journey status | Yes |
| `invited_at_utc` | Complete UTC invitation timestamp | Yes |
| `registered_at_utc` | Complete UTC registration timestamp | No |
| `activated_at_utc` | Complete UTC first-transaction timestamp | No |
| `reward_status` | Referral reward status | No |

## 11. Transaction-attempt tables

### 11.1 `transaction_attempts`

**Grain:** One row represents one transfer journey started by an authenticated customer.

| Column | Description | Required? |
| --- | --- | --- |
| `transaction_attempt_id` | Unique attempt identifier | Yes |
| `customer_id` | Customer starting the journey | Yes |
| `started_at_utc` | Complete UTC start timestamp | Yes |
| `last_activity_at_utc` | Complete UTC most recent activity timestamp | Yes |
| `last_completed_step` | Most advanced completed step | No |
| `send_amount` | Amount entered by the customer | No |
| `send_currency` | GBP or EUR | No |
| `destination_country_code` | Selected destination | No |
| `beneficiary_id` | Selected beneficiary | No |
| `collection_method` | Selected delivery method | No |
| `quoted_exchange_rate_id` | Rate displayed to the customer | No |
| `attempt_status` | Latest/final attempt status | Yes |
| `transaction_id` | Transaction created after submission | No |
| `submitted_at_utc` | Complete UTC submission timestamp | No |
| `created_at_utc` | Complete UTC row-creation timestamp | Yes |
| `updated_at_utc` | Complete UTC row-update timestamp | Yes |

**Attempt statuses:** `InProgress`, `IncompleteDraft`, `Submitted`, `Expired`.

Fields are nullable because customers provide information progressively. `transaction_id` remains null unless submission creates an official remittance instruction.

### 11.2 `transaction_attempt_events`

**Grain:** One row represents one event during one transaction attempt at one UTC timestamp.

| Column | Description | Required? |
| --- | --- | --- |
| `transaction_attempt_event_id` | Unique event identifier | Yes |
| `transaction_attempt_id` | Related attempt | Yes |
| `event_type` | Journey event | Yes |
| `step_name` | Transfer-journey step | Yes |
| `step_sequence` | Numerical step order | Yes |
| `event_timestamp_utc` | Complete UTC event timestamp | Yes |
| `validation_result` | Validation outcome | No |
| `error_code` | Non-sensitive error code | No |
| `created_at_utc` | Complete UTC ingestion timestamp | Yes |

## 12. Transaction tables

### 12.1 `transactions`

**Grain:** One row represents one submitted remittance instruction.

| Column | Description | Required? |
| --- | --- | --- |
| `transaction_id` | Unique transaction reference | Yes |
| `transaction_attempt_id` | Submitted attempt creating the transaction | Yes |
| `customer_id` | Sending customer | Yes |
| `beneficiary_id` | Receiving beneficiary | Yes |
| `send_amount` | Native sending amount | Yes |
| `send_currency` | GBP or EUR | Yes |
| `send_amount_gbp_equivalent` | Historical GBP-equivalent amount | Yes |
| `receive_amount` | Amount intended for beneficiary | Yes |
| `receive_currency` | Destination currency | Yes |
| `transfer_fee` | Fee charged in sending currency | Yes |
| `customer_exchange_rate` | Rate applied to the transfer | Yes |
| `market_exchange_rate_id` | Historical market-rate record used | Yes |
| `collection_method` | Bank, wallet or cash | Yes |
| `current_transaction_status` | Latest canonical transaction status | Yes |
| `initiated_at_utc` | Complete UTC submission timestamp | Yes |
| `deposited_at_utc` | Complete UTC beneficiary-receipt timestamp | No |
| `created_at_utc` | Complete UTC row-creation timestamp | Yes |
| `updated_at_utc` | Complete UTC row-update timestamp | Yes |

**Canonical statuses:** `Initiated`, `AwaitingPayment`, `PaymentConfirmationPending`, `PaymentConfirmed`, `PaymentException`, `ComplianceHold`, `Processing`, `Deposited`, `Failed`, `Cancelled`, `RefundPending`, `Refunded`, `Reversed`.

Submitted transactions receive IDs even if they later fail or are cancelled. Incomplete drafts do not.

### 12.2 `transaction_status_history`

**Grain:** One row represents one status entered by one transaction at one UTC timestamp.

| Column | Description | Required? |
| --- | --- | --- |
| `transaction_status_event_id` | Unique event identifier | Yes |
| `transaction_id` | Related transaction | Yes |
| `source_status` | Original source-system status | Yes |
| `canonical_status` | Standardised analytical status | Yes |
| `event_timestamp_utc` | Complete UTC event timestamp | Yes |
| `reason_code` | Non-sensitive reason | No |
| `source_system` | System producing the event | Yes |
| `source_event_sequence` | Source ordering value | No |
| `created_at_utc` | Complete UTC ingestion timestamp | Yes |

The current transaction status must agree with the latest valid history event. Invalid transitions and late-arriving events will be retained and flagged.

## 13. Funding-payment tables

### 13.1 `payment_attempts`

**Grain:** One row represents one attempt to fund one submitted transaction.

| Column | Description | Required? |
| --- | --- | --- |
| `payment_attempt_id` | Unique funding-attempt identifier | Yes |
| `transaction_id` | Transaction being funded | Yes |
| `payment_method` | Card, Apple Pay, bank transfer or other | Yes |
| `payment_provider` | Fictional provider/acquirer | Yes |
| `payment_amount` | Amount attempted | Yes |
| `payment_currency` | Funding currency | Yes |
| `provider_reference_token` | Synthetic/tokenised provider reference | No |
| `current_payment_status` | Latest funding status | Yes |
| `submitted_at_utc` | Complete UTC payment-submission timestamp | Yes |
| `confirmed_at_utc` | Complete UTC confirmation timestamp | No |
| `created_at_utc` | Complete UTC row-creation timestamp | Yes |
| `updated_at_utc` | Complete UTC row-update timestamp | Yes |

One transaction may have several payment attempts because the customer can retry with another card or payment method.

### 13.2 `payment_status_history`

**Grain:** One row represents one status entered by one funding attempt at one UTC timestamp.

| Column | Description | Required? |
| --- | --- | --- |
| `payment_status_event_id` | Unique event identifier | Yes |
| `payment_attempt_id` | Related payment attempt | Yes |
| `source_status` | Original provider status | Yes |
| `canonical_status` | Standard payment status | Yes |
| `event_timestamp_utc` | Complete UTC event timestamp | Yes |
| `reason_code` | Non-sensitive outcome reason | No |
| `source_system` | System producing the event | Yes |
| `created_at_utc` | Complete UTC ingestion timestamp | Yes |

**Canonical payment statuses:** `Submitted`, `Authorised`, `ConfirmationPending`, `Confirmed`, `Declined`, `Failed`, `Cancelled`, `RefundPending`, `Refunded`, `Reversed`.

A confirmation arriving after transaction cancellation must be preserved and flagged as `PaymentConfirmedAfterCancellation` for reconciliation.

Payment timing will be classified as follows:

| Elapsed time after payment submission | Classification |
| --- | --- |
| 0–30 seconds | Normal confirmation window |
| More than 30 seconds | Delayed confirmation |
| More than 2 minutes | `PaymentConfirmationPending` |
| More than 10 minutes | Operational escalation while still pending |
| More than 24 hours | `PaymentException` requiring formal investigation |

## 14. Beneficiary-payout tables

### 14.1 `payout_attempts`

**Grain:** One row represents one attempt to deliver funds for one transaction to its beneficiary.

| Column | Description | Required? |
| --- | --- | --- |
| `payout_attempt_id` | Unique payout-attempt identifier | Yes |
| `transaction_id` | Related transaction | Yes |
| `payout_partner` | Fictional delivery partner | Yes |
| `collection_method` | Bank, wallet or cash | Yes |
| `payout_amount` | Amount delivered/attempted | Yes |
| `payout_currency` | Receiving currency | Yes |
| `partner_reference_token` | Synthetic/tokenised partner reference | No |
| `current_payout_status` | Latest payout status | Yes |
| `submitted_at_utc` | Complete UTC payout-submission timestamp | Yes |
| `completed_at_utc` | Complete UTC payout-completion timestamp | No |
| `created_at_utc` | Complete UTC row-creation timestamp | Yes |
| `updated_at_utc` | Complete UTC row-update timestamp | Yes |

### 14.2 `payout_status_history`

**Grain:** One row represents one status entered by one payout attempt at one UTC timestamp.

| Column | Description | Required? |
| --- | --- | --- |
| `payout_status_event_id` | Unique event identifier | Yes |
| `payout_attempt_id` | Related payout attempt | Yes |
| `source_status` | Original partner status | Yes |
| `canonical_status` | Standard payout status | Yes |
| `event_timestamp_utc` | Complete UTC event timestamp | Yes |
| `reason_code` | Non-sensitive outcome reason | No |
| `source_system` | System producing the event | Yes |
| `created_at_utc` | Complete UTC ingestion timestamp | Yes |

**Canonical payout statuses:** `Submitted`, `Accepted`, `Processing`, `Deposited`, `Failed`, `Cancelled`, `Reversed`.

## 15. Refund tables

### 15.1 `refunds`

**Grain:** One row represents one refund instruction against one confirmed funding payment.

| Column | Description | Required? |
| --- | --- | --- |
| `refund_id` | Unique refund identifier | Yes |
| `transaction_id` | Related transaction | Yes |
| `payment_attempt_id` | Funding payment being refunded | Yes |
| `refund_type` | Full or partial | Yes |
| `refund_amount` | Amount instructed for return | Yes |
| `refund_currency` | Refund currency | Yes |
| `refund_reason_code` | Non-sensitive reason | Yes |
| `current_refund_status` | Latest refund status | Yes |
| `requested_at_utc` | Complete UTC request timestamp | Yes |
| `completed_at_utc` | Complete UTC completion timestamp | No |
| `created_at_utc` | Complete UTC row-creation timestamp | Yes |
| `updated_at_utc` | Complete UTC row-update timestamp | Yes |

### 15.2 `refund_status_history`

**Grain:** One row represents one status entered by one refund at one UTC timestamp.

| Column | Description | Required? |
| --- | --- | --- |
| `refund_status_event_id` | Unique event identifier | Yes |
| `refund_id` | Related refund | Yes |
| `refund_status` | Status entered | Yes |
| `event_timestamp_utc` | Complete UTC event timestamp | Yes |
| `reason_code` | Non-sensitive reason | No |
| `created_at_utc` | Complete UTC ingestion timestamp | Yes |

**Statuses:** `Requested`, `Approved`, `Submitted`, `Processing`, `Completed`, `Failed`, `Cancelled`.

A control must identify transactions that appear both fully deposited to the beneficiary and fully refunded to the customer without a documented corrective process.

## 16. Exchange-rate table

### 16.1 `exchange_rates`

**Grain:** One row represents one rate for one currency pair, rate type, source and effective UTC timestamp.

| Column | Description | Required? |
| --- | --- | --- |
| `exchange_rate_id` | Unique rate identifier | Yes |
| `base_currency` | Currency being converted | Yes |
| `quote_currency` | Currency received per base unit | Yes |
| `rate_type` | Market, customer or internal reporting rate | Yes |
| `rate_value` | Exchange-rate value | Yes |
| `rate_source` | Fictional/source provider | Yes |
| `effective_from_utc` | Complete UTC start timestamp | Yes |
| `effective_to_utc` | Complete UTC end timestamp | No |
| `created_at_utc` | Complete UTC row-creation timestamp | Yes |

Rates must be greater than zero. Overlapping effective periods for the same currency pair, rate type and source will be flagged.

## 17. Compliance-review tables

### 17.1 `compliance_reviews`

**Grain:** One row represents one compliance review opened against one customer or transaction.

| Column | Description | Required? |
| --- | --- | --- |
| `compliance_review_id` | Unique review identifier | Yes |
| `customer_id` | Customer under review | Yes |
| `transaction_id` | Transaction under review | No |
| `review_type` | Customer, transaction, sanctions, document or other | Yes |
| `trigger_rule_code` | Non-sensitive rule that opened the review | Yes |
| `risk_level` | Low, medium or high | Yes |
| `current_review_status` | Latest review status | Yes |
| `review_outcome` | Final decision | No |
| `opened_at_utc` | Complete UTC opening timestamp | Yes |
| `closed_at_utc` | Complete UTC closing timestamp | No |
| `created_at_utc` | Complete UTC row-creation timestamp | Yes |
| `updated_at_utc` | Complete UTC row-update timestamp | Yes |

### 17.2 `compliance_review_history`

**Grain:** One row represents one status event for one compliance review at one UTC timestamp.

| Column | Description | Required? |
| --- | --- | --- |
| `compliance_review_event_id` | Unique event identifier | Yes |
| `compliance_review_id` | Related review | Yes |
| `review_status` | Status entered | Yes |
| `event_timestamp_utc` | Complete UTC event timestamp | Yes |
| `reason_code` | Non-sensitive reason | No |
| `reviewer_role` | Fictional reviewer role | No |
| `created_at_utc` | Complete UTC ingestion timestamp | Yes |

**Review statuses:** `Opened`, `Assigned`, `UnderReview`, `AdditionalInformationRequired`, `Approved`, `Rejected`, `Escalated`, `Closed`.

## 18. Current state and event history

Summary tables answer the current-state question:

> What is the latest known condition of this record?

Event-history tables answer:

> What happened, in which order, and at what complete dates and times?

For every current-status field, a data-quality test will compare the summary value with the latest valid history event. When multiple events have the same event timestamp, a documented secondary order such as `source_event_sequence` or `created_at_utc` will be used.

## 19. Important analytical duration definitions

### 19.1 Registration completion time

```text
AccountCreated event timestamp - AttemptStarted event timestamp
```

### 19.2 Document verification time

```text
First Approved timestamp - First Submitted timestamp
```

Customer waiting intervals between `AdditionalInformationRequired` and `Resubmitted` will be summed separately from NovaPay processing time.

### 19.3 Payment-confirmation time

```text
Confirmed timestamp - payment Submitted timestamp
```

### 19.4 End-to-end transaction completion time

```text
Beneficiary Deposited timestamp - transaction Initiated timestamp
```

### 19.5 Status duration

```text
Next status-event timestamp - current status-event timestamp
```

Terminal statuses have no subsequent duration unless a reporting cut-off calculation is explicitly required.

## 20. Initial data-quality rules

1. Every primary key must be unique and non-null.
2. Every populated foreign key must reference an existing parent row.
3. A completed registration attempt must have a customer ID.
4. An abandoned registration attempt must not create a customer ID.
5. An `IncompleteDraft` transaction attempt must not have a transaction ID.
6. A submitted transaction attempt must have exactly one transaction ID.
7. A transaction ID may exist for failed or cancelled transactions because submission, not success, creates the transaction.
8. Current statuses must equal the latest valid event-history statuses.
9. Event timestamps must not contain impossible future dates.
10. Deposited timestamps must not precede initiated timestamps.
11. Document-status events must not precede document submission.
12. Amounts and exchange rates must be positive unless a documented correction record permits otherwise.
13. GBP and EUR native amounts must not be summed without conversion.
14. A payment confirmation received after cancellation must create an exception.
15. A transaction must not be both fully paid to the beneficiary and fully refunded without a documented corrective process.
16. Proof-of-address and source-of-funds requirements must not be created solely because identity verification was completed.
17. The £10,000 threshold calculation must use the documented historical GBP-equivalent value and agreed observation window.
18. Invalid rows will be quarantined with a reason rather than silently deleted.

## 21. Privacy and retention rules

- The repository will contain synthetic information only.
- Passwords, card numbers, bank-account details, document images and real document numbers will not be stored.
- Public Power BI reports will not display exact names, dates of birth, addresses or document references.
- Age bands and aggregated geography will be used where appropriate.
- Operational evidence will not be overwritten merely because a later decision changes.
- Rejected or expired documents will be retained only according to a documented fictional retention schedule.
- At the end of the retention period, records will be deleted or anonymised according to the applicable rule.
- Access-control examples will use fictional roles and row-level security.

## 22. Modelling reasoning

### 22.1 Why transaction IDs do not identify status-history rows uniquely

The same transaction ID appears once for every status the transaction enters. Each history row therefore requires its own `transaction_status_event_id`, while `transaction_id` acts as a foreign key.

### 22.2 Why abandoned attempts have null transaction IDs

An official transaction ID is created after successful transaction submission. An attempt that ends before submission never becomes a submitted remittance instruction and therefore retains a null transaction ID.

### 22.3 Why one transaction can have several payment attempts

The first card may be declined or the customer may change to another card, Apple Pay or bank transfer. Each funding attempt requires a separate ID and status history while remaining linked to the same remittance instruction.

### 22.4 Why late events are retained

A payment confirmation received after transaction cancellation may show that the customer was charged. The event must be retained for audit and reconciliation and must create an operational exception. Deleting it would remove evidence and increase the risk of an incorrect payout or refund.

### 22.5 Identity verification versus overall eligibility

A customer may remain identity-verified using a valid approved identity document while proof of address or source-of-funds evidence is not required. When the fictional £10,000 threshold or another risk trigger applies, the customer may remain identity-verified while their transaction eligibility becomes `RestrictedPendingReview` until the additional requirements are satisfied.

### 22.6 Why rejected documents remain temporarily

Rejected documents form part of the verification and audit history and may support complaints, provider reconciliation and compliance investigation. They are not retained indefinitely; they follow the documented retention and deletion schedule.

## 23. Confirmed business and generation rules

1. Sending markets are the United Kingdom, Ireland, France, Germany, Spain and Australia. Sending currencies are GBP, EUR and AUD.
2. Destination countries are Nigeria, Ghana, Zambia, Cameroon and Zimbabwe, using the documented synthetic payout-currency assumptions.
3. The fictional £10,000 compliance threshold uses a rolling 12-month window.
4. The threshold calculation uses prior eligible deposited GBP-equivalent volume plus the GBP-equivalent value of the current submitted transaction.
5. The transaction that crosses the threshold enters `ComplianceHold` before payout.
6. Requirements created by the threshold remain active if the triggering transaction later fails or is cancelled. They remain active until satisfied or explicitly withdrawn by Compliance.
7. Registration and transaction attempts become abandoned after 20 consecutive minutes without activity. A resumable saved journey may retain its attempt ID according to the configured resumption rule.
8. Payment confirmation is delayed after 30 seconds, becomes `PaymentConfirmationPending` after 2 minutes, receives operational escalation after 10 minutes and becomes `PaymentException` after 24 hours.
9. The straight-through payout target is 2 minutes from `PaymentConfirmed` to `Deposited`.
10. The overall completion target is 5 minutes from `Initiated` to `Deposited`. Compliance-held cases are reported separately from the normal straight-through SLA.
11. A partial refund does not remove the customer from the active-customer count and does not alter gross remittance volume. It reduces net remittance volume and net revenue where applicable.
12. Portfolio exchange rates are labelled `SyntheticMarketRate`. No rate will be represented as XE data unless it is obtained through a legitimate documented source. Historical effective-time rates, rather than current rates, are used for GBP-equivalent calculations.
13. Identity evidence remains valid until its documented expiry date unless superseded or invalidated earlier.
14. Proof of address is accepted according to a fictional recency rule and is reviewed again after 12 months or a new compliance trigger.
15. Source-of-funds evidence satisfies the applicable review but may be requested again after a new trigger.
16. Each beneficiary profile belongs to one customer. Two customers sending to the same recipient maintain separate beneficiary profiles.
17. Status-transition rules will be implemented as controlled reference data. Impossible transitions are retained as exceptions and never silently removed.

## 24. Next modelling stage

After the decisions above are confirmed, the project will:

1. assign SQL Server data types and maximum lengths to every field;
2. define primary-key, foreign-key, uniqueness and check constraints;
3. produce an entity-relationship diagram;
4. create SQL data-definition scripts;
5. define synthetic-data generation rules and probabilities;
6. generate a small test dataset before scaling to the full portfolio volume.
