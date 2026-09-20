# NovaPay Status-Transition Rules

## 1. Purpose

This document defines which status changes are permitted for the principal NovaPay business processes. It supplements the source data model by distinguishing a valid status value from a valid movement between two statuses.

The rules support:

- operational controls;
- synthetic-data generation;
- data-quality testing;
- exception identification;
- reconciliation;
- auditability;
- later SQL implementation.

All examples and policies are fictional and are used only for this portfolio project.

## 2. Core concepts

### 2.1 State

A state is the latest known condition of a business record, such as `Processing`, `Deposited` or `Cancelled`.

### 2.2 Event

An event records that a business record entered a state at a complete UTC timestamp. Historical events are preserved even after the current state changes.

### 2.3 Transition

A transition is movement from one state to another:

```text
Current status → Proposed status
```

### 2.4 Transition categories

| Category | Meaning | Example |
| --- | --- | --- |
| Initial | Creates the first state | `NULL → Initiated` |
| Normal | Expected forward movement | `Processing → Deposited` |
| Exception | Movement caused by an operational problem | `ConfirmationPending → PaymentException` |
| Recovery | Resolution of an exception | `PaymentException → Confirmed` |
| Manual | Requires authorised human action | `Suspended → Active` |
| Terminal | Ends that particular process or attempt | `Processing → Deposited` |

### 2.5 Terminal does not mean events are deleted

A terminal state normally ends further processing for that record. A late message may still arrive. The late message must be preserved, classified and reconciled rather than silently deleted or allowed to restart another process automatically.

## 3. Transition reference-data design

The SQL implementation will use controlled reference data with fields such as:

| Field | Purpose |
| --- | --- |
| `process_type` | Registration, transaction, payment, payout, refund or another process |
| `from_status` | Current status |
| `to_status` | Proposed next status |
| `transition_type` | Normal, exception, recovery or manual |
| `is_allowed` | Whether the transition is permitted |
| `requires_reason` | Whether a reason code is mandatory |
| `requires_approval` | Whether authorised approval is required |
| `creates_exception` | Whether an exception record must be created |
| `is_terminal_transition` | Whether the target normally ends the process |

Omitting a transition from the allowed reference data means it is invalid by default.

## 4. General processing rules

1. Original source events are retained in the raw layer.
2. A source event is not automatically accepted as a valid canonical transition.
3. Duplicate messages may be retained in raw ingestion but must not become duplicate genuine business events in the curated history.
4. Invalid transitions are quarantined or flagged for investigation.
5. Late-arriving events are ordered using event time, source sequence and ingestion time.
6. Current-status summaries must equal the latest valid canonical history event.
7. Manual and exceptional transitions require documented reason codes.
8. A status in one process must not automatically overwrite the status of another process.
9. Transaction, payment, payout and refund statuses remain separate.
10. No event is deleted merely because it creates an operational or financial exception.

## 5. Registration-attempt transitions

### 5.1 Status definitions

| Status | Meaning |
| --- | --- |
| `InProgress` | Registration is actively being completed |
| `Abandoned` | No activity for 20 consecutive minutes before completion |
| `Resumed` | Customer returned to a resumable saved journey |
| `Completed` | Account was created successfully |
| `Failed` | Registration could not complete because of an unrecoverable error |

### 5.2 Allowed transitions

| From | To | Type | Notes |
| --- | --- | --- | --- |
| `NULL` | `InProgress` | Initial | Registration attempt begins |
| `InProgress` | `Completed` | Normal | Customer account created |
| `InProgress` | `Abandoned` | Exception | Twenty minutes without activity |
| `InProgress` | `Failed` | Exception | Unrecoverable technical or validation failure |
| `Abandoned` | `Resumed` | Recovery | Customer returns within the allowed resumption period |
| `Resumed` | `Completed` | Normal | Resumed journey completes |
| `Resumed` | `Abandoned` | Exception | Resumed journey becomes inactive again |
| `Resumed` | `Failed` | Exception | Resumed journey fails |

`Completed` and `Failed` are terminal for that attempt. Starting again creates a new attempt.

## 6. Transaction-attempt transitions

### 6.1 Status definitions

| Status | Meaning |
| --- | --- |
| `InProgress` | Customer is building a transfer instruction |
| `IncompleteDraft` | No activity for 20 minutes before submission |
| `Submitted` | Official transaction reference was created |
| `Expired` | Draft exceeded the permitted resumption period |

### 6.2 Allowed transitions

| From | To | Type | Notes |
| --- | --- | --- | --- |
| `NULL` | `InProgress` | Initial | Customer starts the transfer journey |
| `InProgress` | `Submitted` | Normal | Submission creates a transaction ID |
| `InProgress` | `IncompleteDraft` | Exception | Twenty minutes without activity |
| `IncompleteDraft` | `InProgress` | Recovery | Customer resumes the same saved attempt |
| `IncompleteDraft` | `Expired` | Terminal | Resumption window ends |

An `IncompleteDraft` must not have a transaction ID. `Submitted` is terminal for the attempt but creates the separate transaction process.

## 7. Customer-account transitions

| From | To | Type | Approval? | Notes |
| --- | --- | --- | ---: | --- |
| `NULL` | `PendingVerification` | Initial | No | Account created |
| `PendingVerification` | `Active` | Normal | No | Initial identity requirement satisfied |
| `PendingVerification` | `Restricted` | Exception | Yes | Additional review or restriction required |
| `PendingVerification` | `Closed` | Terminal | Yes | Onboarding rejected or customer withdraws |
| `Active` | `Restricted` | Exception | Yes | Compliance requirement or risk restriction |
| `Active` | `Suspended` | Exception | Yes | Stronger temporary restriction |
| `Active` | `Closed` | Terminal | Yes | Account closure |
| `Restricted` | `Active` | Recovery | Yes | Restriction resolved |
| `Restricted` | `Suspended` | Exception | Yes | Risk escalates |
| `Restricted` | `Closed` | Terminal | Yes | Account closed |
| `Suspended` | `Active` | Recovery | Yes | Authorised reinstatement |
| `Suspended` | `Restricted` | Recovery | Yes | Partial reinstatement |
| `Suspended` | `Closed` | Terminal | Yes | Account closed |

`Closed → Active` is not a normal transition. Reopening requires a separately documented exceptional process or a new account according to policy.

## 8. Customer-document transitions

| From | To | Type | Notes |
| --- | --- | --- | --- |
| `NULL` | `Submitted` | Initial | Document submitted |
| `Submitted` | `AutomatedReview` | Normal | Automated checks begin |
| `Submitted` | `ManualReview` | Normal | Routed directly to a reviewer |
| `Submitted` | `Rejected` | Exception | Submission is invalid or unacceptable |
| `AutomatedReview` | `Approved` | Normal | Automated approval |
| `AutomatedReview` | `ManualReview` | Normal | Human judgement required |
| `AutomatedReview` | `AdditionalInformationRequired` | Exception | More evidence required |
| `AutomatedReview` | `Rejected` | Exception | Automated checks reject the document |
| `ManualReview` | `Approved` | Normal | Reviewer approves the document |
| `ManualReview` | `AdditionalInformationRequired` | Exception | Reviewer requests more information |
| `ManualReview` | `Rejected` | Exception | Reviewer rejects the document |
| `AdditionalInformationRequired` | `Submitted` | Recovery | Corrected or additional evidence submitted |
| `Approved` | `Expired` | Terminal | Validity period ends |
| `Approved` | `Superseded` | Terminal | Replaced before expiry |
| `Rejected` | `Superseded` | Terminal | A new document version replaces it |
| `Expired` | `Superseded` | Terminal | A renewed document replaces it |

Rejected, expired and superseded document records remain in history according to the retention policy. A replacement receives a new document ID.

## 9. Compliance-requirement transitions

| From | To | Type | Notes |
| --- | --- | --- | --- |
| `NULL` | `Required` | Initial | Requirement triggered |
| `Required` | `AwaitingDocument` | Normal | Customer notified |
| `Required` | `Waived` | Manual | Authorised waiver |
| `Required` | `Withdrawn` | Manual | Compliance withdraws requirement |
| `AwaitingDocument` | `Submitted` | Normal | Customer provides evidence |
| `AwaitingDocument` | `Waived` | Manual | Requirement waived |
| `AwaitingDocument` | `Withdrawn` | Manual | Requirement withdrawn |
| `Submitted` | `UnderReview` | Normal | Review begins |
| `UnderReview` | `Approved` | Normal | Requirement satisfied |
| `UnderReview` | `Rejected` | Exception | Evidence does not satisfy requirement |
| `UnderReview` | `AdditionalInformationRequired` | Exception | More evidence needed |
| `UnderReview` | `Waived` | Manual | Authorised waiver |
| `AdditionalInformationRequired` | `Submitted` | Recovery | Customer resubmits evidence |
| `Approved` | `Expired` | Terminal | Approved evidence is no longer current |

If the triggering transaction fails or is cancelled, the requirement remains active until `Approved`, `Waived` or `Withdrawn` by Compliance.

## 10. Transaction transitions

### 10.1 Allowed transitions

| From | To | Type | Exception/approval rule |
| --- | --- | --- | --- |
| `NULL` | `Initiated` | Initial | Submitted attempt creates transaction |
| `Initiated` | `AwaitingPayment` | Normal | Funding required |
| `Initiated` | `ComplianceHold` | Exception | Pre-payment review required |
| `Initiated` | `Cancelled` | Terminal | Customer/system cancellation |
| `Initiated` | `Failed` | Terminal | Unrecoverable creation failure |
| `AwaitingPayment` | `PaymentConfirmationPending` | Exception | Confirmation exceeds two minutes |
| `AwaitingPayment` | `PaymentConfirmed` | Normal | Funding confirmed |
| `AwaitingPayment` | `Cancelled` | Terminal | Customer/system cancellation |
| `AwaitingPayment` | `Failed` | Terminal | Funding process cannot continue |
| `PaymentConfirmationPending` | `PaymentConfirmed` | Recovery | Delayed confirmation arrives |
| `PaymentConfirmationPending` | `PaymentException` | Exception | Pending for more than 24 hours |
| `PaymentConfirmationPending` | `Cancelled` | Terminal | Transaction cancelled while unresolved |
| `PaymentException` | `PaymentConfirmed` | Recovery | Confirmation eventually arrives; reconciliation required |
| `PaymentException` | `Cancelled` | Terminal | Transaction cancelled |
| `PaymentException` | `Failed` | Terminal | Confirmed unrecoverable failure |
| `PaymentConfirmed` | `ComplianceHold` | Exception | Threshold/risk review required |
| `PaymentConfirmed` | `Processing` | Normal | Ready for beneficiary payout |
| `PaymentConfirmed` | `Cancelled` | Terminal | Authorised cancellation; refund may be required |
| `ComplianceHold` | `Processing` | Recovery | Compliance clears transaction |
| `ComplianceHold` | `Cancelled` | Terminal | Compliance rejects or customer withdraws |
| `Processing` | `Deposited` | Terminal | Beneficiary receives funds |
| `Processing` | `Failed` | Terminal | No further payout retry will occur |
| `Processing` | `Cancelled` | Terminal | Allowed only before confirmed payout |
| `Deposited` | `RefundPending` | Exception | Approved corrective refund; reason and approval required |
| `Deposited` | `Reversed` | Exception | Payout reversal confirmed |
| `Failed` | `RefundPending` | Recovery | Customer paid and refund is required |
| `Cancelled` | `RefundPending` | Recovery | Customer paid before cancellation |
| `RefundPending` | `Refunded` | Terminal | Full refund completed |

### 10.2 Important transaction rules

- `Cancelled → Processing` is invalid.
- `Deposited → Processing` is invalid.
- Payment confirmation after transaction cancellation does not reactivate the transaction.
- A cancelled transaction with late confirmed payment creates a reconciliation exception and, where required, a refund.
- While documents are outstanding, the transaction remains `ComplianceHold`; it does not move to `Processing`.
- A final compliance rejection normally produces `Cancelled`, not a technical `Failed` status.
- If payment was confirmed before compliance rejection, NovaPay initiates the refund process. The customer should not be expected to solve NovaPay's captured-payment reconciliation by requesting a bank recall.

## 11. Funding-payment transitions

| From | To | Type | Notes |
| --- | --- | --- | --- |
| `NULL` | `Submitted` | Initial | Funding attempt submitted |
| `Submitted` | `Authorised` | Normal | Payment authorised but not settled/confirmed |
| `Submitted` | `ConfirmationPending` | Exception | Provider confirmation delayed |
| `Submitted` | `Confirmed` | Normal | Immediate confirmation |
| `Submitted` | `Declined` | Terminal | Provider declines attempt |
| `Submitted` | `Failed` | Terminal | Technical failure confirmed |
| `Submitted` | `Cancelled` | Terminal | Attempt cancelled |
| `Authorised` | `ConfirmationPending` | Exception | Confirmation delayed |
| `Authorised` | `Confirmed` | Normal | Funds confirmed |
| `Authorised` | `Declined` | Terminal | Authorisation not completed |
| `Authorised` | `Reversed` | Terminal | Authorisation reversed |
| `ConfirmationPending` | `Confirmed` | Recovery | Late confirmation arrives |
| `ConfirmationPending` | `Declined` | Terminal | Provider confirms decline |
| `ConfirmationPending` | `Failed` | Terminal | Provider confirms failure |
| `ConfirmationPending` | `Cancelled` | Terminal | Attempt cancelled while unresolved |
| `Confirmed` | `RefundPending` | Normal | Refund initiated |
| `Confirmed` | `Reversed` | Exception | Provider reverses payment |
| `Cancelled` | `Confirmed` | Exception | Late confirmation; reconciliation required |
| `RefundPending` | `Refunded` | Terminal | Refund confirmed |
| `RefundPending` | `Failed` | Exception | Refund attempt failed |

A late `Cancelled → Confirmed` payment transition is accepted as an exception because it reflects the actual payment outcome. It must not change a cancelled transaction back to processing.

## 12. Beneficiary-payout transitions

| From | To | Type | Notes |
| --- | --- | --- | --- |
| `NULL` | `Submitted` | Initial | Payout attempt submitted |
| `Submitted` | `Accepted` | Normal | Partner accepts request |
| `Submitted` | `Processing` | Normal | Partner begins processing |
| `Submitted` | `Failed` | Terminal | Partner confirms failure |
| `Submitted` | `Cancelled` | Terminal | Payout cancelled before processing |
| `Accepted` | `Processing` | Normal | Processing begins |
| `Accepted` | `Failed` | Terminal | Partner confirms failure |
| `Accepted` | `Cancelled` | Terminal | Cancellation confirmed |
| `Processing` | `Deposited` | Terminal | Beneficiary receives funds |
| `Processing` | `Failed` | Terminal | Partner confirms failure |
| `Processing` | `Cancelled` | Terminal | Cancellation confirmed before deposit |
| `Cancelled` | `Deposited` | Exception | Late deposit confirmation; urgent reconciliation required |
| `Deposited` | `Reversed` | Exception | Partner confirms payout reversal |

### 12.1 Retry rule

If the first payout attempt has a definitive `Failed` status, NovaPay may create a new payout attempt linked to the same transaction. The failed attempt remains unchanged in history.

If the first payout attempt is merely delayed, pending or unknown, NovaPay must not create another payout automatically because both attempts could eventually deposit. The pending attempt is escalated and may wait up to the documented 24-hour exception threshold or until the partner provides a definitive response.

## 13. Refund transitions

| From | To | Type | Notes |
| --- | --- | --- | --- |
| `NULL` | `Requested` | Initial | Refund instruction created |
| `Requested` | `Approved` | Normal | Authorised approval |
| `Requested` | `Cancelled` | Terminal | Request withdrawn/rejected |
| `Approved` | `Submitted` | Normal | Sent to payment provider |
| `Approved` | `Cancelled` | Terminal | Approval withdrawn before submission |
| `Submitted` | `Processing` | Normal | Provider processing refund |
| `Submitted` | `Completed` | Terminal | Immediate completion |
| `Submitted` | `Failed` | Exception | Provider confirms failure |
| `Processing` | `Completed` | Terminal | Customer refund completed |
| `Processing` | `Failed` | Exception | Refund fails |
| `Failed` | `Submitted` | Recovery | Authorised retry |

A completed refund event is never deleted. Partial refunds reduce net volume/revenue but do not erase the original deposited transaction or remove the customer from the active-customer count.

## 14. Compliance-review transitions

| From | To | Type | Notes |
| --- | --- | --- | --- |
| `NULL` | `Opened` | Initial | Review created |
| `Opened` | `Assigned` | Normal | Reviewer assigned |
| `Opened` | `UnderReview` | Normal | Review begins immediately |
| `Assigned` | `UnderReview` | Normal | Assigned reviewer begins work |
| `Assigned` | `Escalated` | Exception | Senior/specialist review needed |
| `UnderReview` | `AdditionalInformationRequired` | Exception | Customer evidence required |
| `UnderReview` | `Approved` | Normal | Review clears case |
| `UnderReview` | `Rejected` | Terminal decision | Review rejects case |
| `UnderReview` | `Escalated` | Exception | Higher authority required |
| `AdditionalInformationRequired` | `UnderReview` | Recovery | Evidence received and review resumes |
| `Escalated` | `UnderReview` | Recovery | Escalated case returns to review |
| `Escalated` | `Approved` | Normal | Senior approval |
| `Escalated` | `Rejected` | Terminal decision | Senior rejection |
| `Approved` | `Closed` | Terminal | Review administratively closed |
| `Rejected` | `Closed` | Terminal | Review administratively closed |

The customer-facing communication will use an appropriate general explanation. Sensitive fraud indicators or investigative reasoning are not automatically disclosed.

## 15. Duplicate-event handling

### 15.1 Raw layer

The raw ingestion layer preserves every received message, including repeated messages, with:

- source system;
- provider event reference;
- payload hash;
- source timestamp;
- ingestion timestamp;
- batch/run identifier.

### 15.2 Curated history

Two records with the same trusted provider event reference are treated as duplicate deliveries of the same event unless investigation proves otherwise. Only one becomes a canonical business event.

Where no provider event reference exists, a documented deduplication key may use:

```text
process identifier
+ canonical status
+ source timestamp
+ source system
+ payload hash
```

### 15.3 Idempotency

Reprocessing the same source event must not create another canonical history row or repeat a financial action. This property is called idempotency.

## 16. Late-arriving and out-of-order events

Late events are retained with both:

- `event_timestamp_utc`: when the business event occurred;
- `created_at_utc`: when NovaPay received or stored it.

If an event arrives out of order:

1. preserve the raw message;
2. evaluate the source sequence and timestamps;
3. determine whether it changes the correct historical sequence;
4. rebuild the current status only from valid ordered events;
5. create an exception if the event conflicts with completed financial actions.

## 17. Financial and reconciliation controls

The following conditions create high-priority exceptions:

1. payment confirmed after transaction cancellation;
2. payout deposited after payout cancellation;
3. more than one successful payout for one transaction without an authorised split-payment design;
4. full customer refund plus full beneficiary payout without an authorised corrective-loss case;
5. refund completed for an unconfirmed payment;
6. transaction marked `Deposited` without a deposited payout event;
7. transaction marked `Refunded` without a completed refund event;
8. transaction processing resumed while an active compliance hold remains unresolved.

Full refund after beneficiary deposit is prohibited as a normal flow. If exceptional corrective action authorises it, the deposited event remains, a separate refund is recorded, financial loss is measured and approval/recovery evidence is retained.

## 18. Data-quality tests

1. Every status must exist in the relevant process-status reference data.
2. Every canonical status change must exist in the allowed-transition reference data.
3. Every event must contain a complete UTC timestamp.
4. Each provider event reference must produce no more than one canonical event per source.
5. Current status must match the latest valid canonical event.
6. Terminal records must not move through an unapproved normal transition.
7. Manual transitions must include an authorised role and reason code.
8. Payment, payout and refund transitions must not automatically overwrite the transaction status.
9. Compliance-held transactions must not enter payout processing before clearance.
10. A retry must not overwrite or delete the failed attempt.

## 19. Scenario decisions

### 19.1 Payment confirmed after cancellation

The payment changes to `Confirmed`; the transaction remains `Cancelled`. NovaPay creates a reconciliation exception and follows the refund process. The expected three-to-five-day customer refund period may be reported operationally but does not alter the actual payment-confirmation timestamp.

### 19.2 Failed or uncertain payout

A definitively failed payout attempt remains `Failed` and a new attempt may be created. A pending or unknown payout is not retried automatically because doing so could cause double beneficiary payment. It is escalated until a definitive outcome or the documented exception threshold.

### 19.3 Compliance rejection

While further documents are requested, the transaction remains `ComplianceHold`. If documentation is approved, it moves to `Processing`. A final rejection normally cancels the transaction. If payment was confirmed, NovaPay initiates a refund rather than telling the customer to arrange a bank recall.

### 19.4 Refund after deposit

The original `Deposited` event is preserved. A separate refund record is required. Full refund after full payout is an exceptional financial-loss case requiring approval, reconciliation and, where possible, recovery action.

### 19.5 Duplicate payout message

Duplicate source deliveries are retained in raw ingestion for audit, but only one is accepted as a canonical business event. Provider references, payload hashes and idempotency keys prevent the repeated message from initiating another action.

## 20. Next implementation stage

The next stage will convert these rules into:

1. SQL reference tables for process statuses;
2. SQL reference tables for allowed transitions;
3. primary-key, foreign-key and uniqueness constraints;
4. validation queries that detect invalid transitions;
5. synthetic-event generation rules;
6. test cases for normal, exception, recovery, duplicate and late-arriving scenarios.
