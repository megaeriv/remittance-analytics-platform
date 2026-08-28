# NovaPay Source Data Model

## 1. Purpose

This document defines the proposed source entities, their grain,
identifiers and relationships for the NovaPay Remittance Analytics
Platform.

The model separates customer journeys, submitted transactions,
payment attempts and their event histories so that operational delays
and incomplete conditions can be analysed correctly.

## 2. Modelling principles

1. Every table must have a clearly defined grain.
2. Every row must have a unique primary key.
3. Foreign keys must identify relationships between entities.
4. Source values must be preserved before analytical standardisation.
5. Current-state records must not replace event histories.
6. Transactions and funding payments must be modelled separately.
7. Different currencies must not be aggregated without conversion.
8. Synthetic data must not reproduce real customer information.

## 3. Proposed source entities

| Table | Grain | Primary key |
| --- | --- | --- |
| `customers` | One row per successfully created customer account | `customer_id` |
| `registration_attempts` | One row per registration journey started | `registration_attempt_id` |
| `registration_attempt_events` | One row per event occurring during a registration attempt | `registration_attempt_event_id` |
| `identity_documents` | One row per identity-document submission | `document_id` |
| `identity_verification_history` | One row per document-verification status event | `verification_event_id` |
| `beneficiaries` | One row per beneficiary | `beneficiary_id` |
| `customer_beneficiary_relationships` | One row per relationship between a customer and beneficiary | `relationship_id` |
| `transaction_attempts` | One row per transfer journey started | `transaction_attempt_id` |
| `transaction_attempt_events` | One row per event occurring during a transaction attempt | `transaction_attempt_event_id` |
| `transactions` | One row per successfully submitted remittance instruction | `transaction_id` |
| `transaction_status_history` | One row per status entered by a transaction at a point in time | `transaction_status_event_id` |
| `payment_attempts` | One row per attempt to fund a submitted transaction | `payment_attempt_id` |
| `payment_status_history` | One row per status entered by a payment attempt at a point in time | `payment_status_event_id` |
| `exchange_rates` | One row per currency pair, rate type and effective timestamp | `exchange_rate_id` |
| `referrals` | One row per referral invitation | `referral_id` |
| `compliance_reviews` | One row per compliance review opened against a transaction | `compliance_review_id` |

## 4. Core relationships

| Parent table | Child table | Relationship |
| --- | --- | --- |
| `registration_attempts` | `customers` | One completed registration attempt may create one customer |
| `registration_attempts` | `registration_attempt_events` | One registration attempt may have many journey events |
| `customers` | `identity_documents` | One customer may submit many identity documents |
| `identity_documents` | `identity_verification_history` | One document may have many verification events |
| `customers` | `customer_beneficiary_relationships` | One customer may have many beneficiary relationships |
| `beneficiaries` | `customer_beneficiary_relationships` | One beneficiary may be related to many customers |
| `customers` | `transaction_attempts` | One customer may start many transaction attempts |
| `transaction_attempts` | `transactions` | One submitted attempt may create one transaction |
| `customers` | `transactions` | One customer may submit many transactions |
| `beneficiaries` | `transactions` | One beneficiary may receive many transactions |
| `transactions` | `transaction_status_history` | One transaction may have many status events |
| `transaction_attempts` | `transaction_attempt_events` | One transaction attempt may have many journey events |
| `transactions` | `payment_attempts` | One transaction may have many payment attempts |
| `payment_attempts` | `payment_status_history` | One payment attempt may have many status events |
| `transactions` | `compliance_reviews` | One transaction may have zero or many compliance reviews |
| `customers` | `referrals` | One customer may create many referral invitations |

## 5. Important distinctions

### 5.1 Incomplete draft

An incomplete draft is a transaction attempt that the customer began
but did not successfully submit. It belongs in `transaction_attempts`
and may not have a `transaction_id`.

### 5.2 Payment confirmation pending

A payment-confirmation-pending case occurs after a transaction was
submitted and a transaction reference was created. The customer's bank
may display a debit, but NovaPay has not received confirmation from the
card acquirer.

This condition requires records in:

- `transactions`;
- `payment_attempts`;
- `payment_status_history`.

It must not be treated as an incomplete draft.

### 5.3 Current state and event history

Current-state fields support quick operational lookup. Event-history
tables preserve the sequence and timing required for duration analysis.

## 6. Open modelling questions

1. Can one beneficiary be associated with several customers?
2. Can one submitted transaction have more than one payment attempt?
3. Can one identity document enter the same verification status more
   than once?
4. Can one transaction have several compliance reviews?
5. Can a customer submit a transaction before identity verification is
   complete?
6. Can a payment confirmation arrive after the transaction has already
   been cancelled?
7. Can a transaction be partially refunded?
8. Can one referral invitation be sent to the same prospect several
   times?


## 7. Attempt capture approach

NovaPay will use both summary and event-level attempt data.

The summary tables, `registration_attempts` and
`transaction_attempts`, contain the latest or final condition of each
attempt. Their fields may be null when a customer has not yet reached
the relevant journey stage.

The event tables, `registration_attempt_events` and
`transaction_attempt_events`, record the sequence and timing of
important journey events. These tables support funnel, abandonment,
validation-error and time-between-step analysis.

Sensitive values such as full names, dates of birth, document numbers
and card details will not be repeated in analytical event records.
Event data will record the step, event type, timestamp, outcome and
non-sensitive error information required for analysis.


## 8. Initial table designs

### 8.1 registration_attempts

**Grain:** One row represents one registration journey started by a
prospective customer.

| Column | Description | Required? |
| --- | --- | --- |
| `registration_attempt_id` | Unique identifier for the registration attempt | Yes |
| `session_id` | Identifier connecting activity within the same application session | Yes |
| `started_at` | Timestamp when registration began | Yes |
| `last_activity_at` | Timestamp of the most recent recorded activity | Yes |
| `completed_at` | Timestamp when account creation completed | No |
| `last_completed_step` | Most advanced successfully completed registration step | No |
| `attempt_status` | Current or final status of the attempt | Yes |
| `acquisition_channel` | Channel that brought the prospect to NovaPay | No |
| `device_type` | Broad device category used for the attempt | No |
| `country_code` | Sending-market country associated with the attempt | No |
| `customer_id` | Customer created from the completed attempt | No |
| `created_at` | Timestamp when the record was created | Yes |
| `updated_at` | Timestamp when the record was last updated | Yes |

**Allowed attempt statuses:**

- `InProgress`
- `Abandoned`
- `Resumed`
- `Completed`
- `Failed`

**Important rule:** `customer_id` must remain null unless the
registration attempt successfully creates a customer account.

### 8.2 registration_attempt_events

**Grain:** One row represents one event occurring during one
registration attempt at one timestamp.

| Column | Description | Required? |
| --- | --- | --- |
| `registration_attempt_event_id` | Unique identifier for the event | Yes |
| `registration_attempt_id` | Registration attempt associated with the event | Yes |
| `event_type` | Type of event recorded | Yes |
| `step_name` | Registration step associated with the event | Yes |
| `step_sequence` | Numerical order of the step | Yes |
| `event_timestamp` | Timestamp when the event occurred | Yes |
| `validation_result` | Result of validation, where applicable | No |
| `error_code` | Non-sensitive code explaining a failure | No |
| `created_at` | Timestamp when the event entered the data source | Yes |

**Example event types:**

- `AttemptStarted`
- `StepViewed`
- `StepCompleted`
- `ValidationFailed`
- `AttemptAbandoned`
- `AttemptResumed`
- `RegistrationSubmitted`
- `AccountCreated`


## 9. Modelling reasoning
## 9. Modelling reasoning

### 9.1 Why `transaction_id` cannot uniquely identify a transaction-status event

One transaction can pass through several statuses during its lifecycle. Therefore, the same `transaction_id` can appear in multiple rows of `transaction_status_history`.

For example:

| `transaction_status_event_id` | `transaction_id` | `status`                   |
| ----------------------------- | ---------------- | -------------------------- |
| TSE001                        | TX001            | Initiated                  |
| TSE002                        | TX001            | PaymentConfirmationPending |
| TSE003                        | TX001            | Processing                 |
| TSE004                        | TX001            | Deposited                  |

In this example, `transaction_id = TX001` appears four times. It identifies the transaction associated with each event, but it does not uniquely identify an individual history row.

Therefore:

* `transaction_status_event_id` is the primary key because it uniquely identifies each status event;
* `transaction_id` is a foreign key because it connects each event to the relevant transaction.

### 9.2 Why an abandoned transaction attempt has a null `transaction_id`

A transaction attempt begins when a customer starts the transfer journey. An official transaction is not created until the customer successfully submits the transfer and NovaPay generates a transaction reference.

If the customer leaves before submission, the attempt does not become an official transaction. The `transaction_id` must therefore remain null.

A transaction does not have to complete successfully to receive a transaction ID. Submitted transactions that later fail, are cancelled, enter payment exception or are refunded still have transaction IDs because they became official submitted remittance instructions.

The distinction is therefore based on submission rather than successful completion.

### 9.3 Why one transaction may have several payment attempts

One submitted transaction may require several funding attempts. For example, a customer's first card may be declined because it has insufficient funds. The customer may then try another card, Apple Pay, bank transfer or another supported payment method.

Each funding attempt needs a separate `payment_attempt_id` because it may have a different:

* payment method;
* provider;
* submission time;
* status journey;
* failure reason;
* confirmation time;
* acquirer reference.

All the payment attempts remain connected to the same `transaction_id` because the underlying instruction to send money has not changed.

The relationship is therefore:

```text
One transaction may have many payment attempts.
```

### 9.4 Why a late payment-confirmation event must be preserved

A payment confirmation that arrives after a transaction has been cancelled must not be deleted. It is a valid late-arriving event and may indicate that the customer was charged even though NovaPay had already cancelled the transaction.

Deleting the event would:

* remove evidence of the customer payment;
* create incorrect reconciliation results;
* prevent Operations from investigating the exception;
* increase the risk that the customer is not refunded correctly;
* weaken the audit history.

The event should be preserved in `payment_status_history` using its actual event timestamp and the timestamp when NovaPay received or processed it.

The system should also create an exception such as:

```text
PaymentConfirmedAfterCancellation
```

This exception should prevent automatic processing until the payment, transaction, payout and refund records have been reconciled.

A control must ensure that the same funds are not both:

* delivered to the beneficiary; and
* fully refunded to the customer.

If both events appear, the case must be flagged for investigation rather than silently corrected or deleted.
