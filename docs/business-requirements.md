# NovaPay Remittance Analytics Platform

## 1. Company background

NovaPay Remittance Ltd is a fictional UK-based money-transfer company serving customers in the United Kingdom and selected European markets who send funds to five African destination countries.

Customers fund transfers primarily in pounds sterling (GBP) and euros (EUR). Beneficiaries receive funds in the currency supported by their destination country and selected collection method. NovaPay earns revenue from transfer fees and the margin between the market exchange rate and the customer exchange rate.

This project uses synthetic data only. It does not contain information belonging to any real customer, employer, payment provider or financial institution.

## 2. Current business problem

NovaPay has reporting and operational-visibility problems across several areas of the business. Management, Operations, Marketing and other teams may use different definitions for measures such as active customers, completed transactions and transaction volume. Consequently, separate reports can produce conflicting figures, reducing confidence in performance reporting and making comparisons unreliable.

Transactions pass through several stages, including incomplete draft, initiated, awaiting payment, payment confirmation pending, compliance hold, processing and deposited. NovaPay currently lacks a consistent method for measuring the time spent at each stage. Operations therefore cannot easily determine whether a delay was caused by customer abandonment, the customer's bank, a card network, the card acquirer, an internal system, Compliance or a payout partner.

Two operationally different situations may both be labelled `Incomplete` by a source system. In the first situation, a customer starts creating a transaction but does not submit it. In the second, the customer submits the transaction and receives a transaction reference, and their bank may show a debit, but NovaPay has not yet received confirmation from the card acquirer because the payment message or data did not complete its journey. Treating these situations as the same condition would hide important customer and payment-system problems.

NovaPay also needs a clearer view of the customer journey from registration and identity verification to first transaction, repeat usage, referral and eventual inactivity. Management needs to identify customers who register and become verified but never complete a transaction, customers who abandon transfers, and customers whose activity declines after experiencing operational delays or payment exceptions.

Without consistent definitions, event-level status tracking and connected customer-journey data, management cannot fully trust its reports or reliably identify where customers, payments and transactions are stalling.

## 3. Project objective

The objective of this project is to design and build an end-to-end analytics platform that transforms synthetic customer, transaction, payment, exchange-rate, referral, identity-verification and compliance data into reliable information for NovaPay's Management, Finance, Operations, Marketing and Compliance teams.

The platform will establish consistent definitions for business metrics, track customers, payments and transactions through each stage of their journeys, and distinguish customer abandonment from payment-system, compliance, operational and partner-related delays. It will provide trusted reporting on customer activity, financial performance, transaction completion, payment exceptions, verification, retention and operational service levels to support evidence-based decisions.

## 4. Stakeholders

| Stakeholder | Information needed | Decisions supported |
| --- | --- | --- |
| Managing Director | Active customers, transaction volume, revenue, growth, service performance and forecasts | Set targets, allocate resources, monitor strategy and investigate underperformance |
| Finance Manager | Completed transaction volume, fees, foreign-exchange margin, refunds, reversals and reconciliations | Reconcile financial records, investigate differences, monitor refunds and assess financial performance |
| Operations Manager | Transaction and payment status transitions, incomplete transactions, failures, exceptions and processing durations | Identify bottlenecks, distinguish customer issues from system or partner issues, escalate incidents and allocate operational capacity |
| Marketing Manager | Registrations, verification, activation, referrals, repeat usage, retention and churn | Improve onboarding, select customer segments, design acquisition and retention campaigns and assess whether poor experiences affect customer behaviour |
| Compliance Manager | Verification times, expired documents, transaction holds, triggered rules, review outcomes and review durations | Monitor workload, address verification and review delays, assess control effectiveness and manage compliance service levels |

## 5. Business questions

### 5.1 Executive performance

1. How did active customers change this month compared with the previous month and the same month in the previous year?
2. How did completed transaction count change this month compared with the previous month?
3. How did completed remittance volume in GBP and EUR change this month compared with the previous month?
4. How did GBP-equivalent remittance volume and total revenue change over the last 24 months?
5. Which sending markets, destination countries and corridors generated the highest transaction volume and revenue?
6. How does actual active-customer performance compare with the previously agreed target or forecast?

### 5.2 Customer acquisition and activation

7. How many customers started registration, completed registration and became verified this month compared with the previous month?
8. What percentage of new registrants became verified within the agreed verification service level?
9. What percentage of new registrants completed their first successful transfer within 30 days?
10. How many verified customers have never completed a successful transaction?
11. At which stage do customers most frequently leave the journey between registration and first successful transaction?

### 5.3 Customer engagement, referrals and retention

12. How many active customers were new, repeat or reactivated customers during the reporting period?
13. What percentage of newly activated customers completed another transaction within 90 days?
14. How many customers successfully referred another person this month compared with the previous month?
15. What percentage of referred prospects registered, became verified and completed a first transaction?
16. Is customer inactivity associated with previous failed transactions, payment exceptions, compliance holds or long completion times?
17. How many previously active customers have completed no transaction for at least 90 days?

### 5.4 Transaction and payment operations

18. How many transaction attempts ended as incomplete drafts this month, and what was the incomplete-draft rate?
19. How many submitted card transactions entered payment-confirmation pending, and what percentage remained unresolved beyond the agreed threshold?
20. How long did card-acquirer confirmation take, and how did this vary by payment provider and time of day?
21. How many transactions failed this month, and what were the most frequent failure reasons?
22. What were the median, average and 90th-percentile completion times this month compared with the previous month?
23. How long did transactions remain in each status, and at which stages did the greatest delays occur?
24. Which payment methods, collection methods, corridors and partners had the highest failure or delay rates?
25. What percentage of eligible transactions reached `Deposited` within the agreed service-level target?

### 5.5 Finance and reconciliation

26. What were completed remittance volume, transfer-fee revenue, foreign-exchange margin and total revenue for the reporting period?
27. How much transaction value was refunded or reversed, and why?
28. Do customer payment records, card-acquirer confirmations and completed transaction records reconcile?
29. How many payment exceptions involve a possible customer debit without confirmed receipt by NovaPay?

### 5.6 Compliance and identity verification

30. What proportion of transactions entered compliance hold, and which rules triggered the reviews?
31. What were the median and 90th-percentile identity-verification times?
32. How many verification cases exceeded the agreed service-level target?
33. How many customers had an identity document expire, and how many renewed it before or after expiry?
34. How long did compliance reviews take, and how did review outcomes vary by risk level and rule?

## 6. Business process and status definitions

### 6.1 Why source and analytical statuses are separated

NovaPay will preserve every status exactly as received from a source system in `source_status`. A separate `canonical_status` will translate ambiguous source values into consistent analytical categories. This preserves the original evidence while providing reliable reporting definitions.

For example, two source records may both contain `Incomplete`, but other event information may allow the analytical platform to classify one as `IncompleteDraft` and the other as `PaymentConfirmationPending`.

### 6.2 Canonical transaction statuses

| Canonical status | Definition |
| --- | --- |
| `IncompleteDraft` | The customer began creating a transfer but did not successfully submit it. No completed transaction submission exists. |
| `Initiated` | The customer successfully submitted the transfer and NovaPay generated a transaction reference. |
| `AwaitingPayment` | The transfer was submitted, but the customer has not completed the payment process. |
| `PaymentConfirmationPending` | The customer completed the payment step and may have been debited, but confirmation from the card acquirer has not reached NovaPay. |
| `PaymentConfirmed` | NovaPay received confirmation that the customer's payment was accepted. |
| `PaymentException` | Payment confirmation remains unresolved beyond the agreed operational threshold or requires manual investigation. |
| `ComplianceHold` | The transaction is temporarily held for compliance review. |
| `Processing` | NovaPay or its payout partner is processing the transfer for delivery. |
| `Deposited` | The beneficiary successfully received the funds. |
| `Failed` | The transaction could not be completed. |
| `Cancelled` | The customer or NovaPay cancelled the transaction before completion. |
| `RefundPending` | A refund has been approved or initiated but has not yet been confirmed as completed. |
| `Refunded` | The customer's funds were returned successfully. |
| `Reversed` | A previously recorded financial event was reversed. |

### 6.3 Transaction status and payment status are different

A transaction describes the customer's remittance instruction. A payment describes the movement of the sender's money to NovaPay. Their statuses must therefore be stored and analysed separately.

| Example transaction status | Example payment status | Interpretation |
| --- | --- | --- |
| `Initiated` | `ConfirmationPending` | A transaction reference exists, but payment confirmation has not arrived |
| `Processing` | `Confirmed` | Payment was confirmed and the transfer is being delivered |
| `Cancelled` | `RefundPending` | The transfer was cancelled, but the money has not yet been confirmed as returned |
| `Refunded` | `Refunded` | The transfer ended and the customer's money was returned |

### 6.4 Event-history requirement

The platform will not rely only on a transaction's current status. It will maintain status histories so that the time spent at every stage can be measured.

The grain of `transaction_status_history` is:

> One row represents one status entered by one transaction at one point in time.

The grain of `payment_status_history` is:

> One row represents one status entered by one payment attempt at one point in time.

## 7. Initial metric definitions

### 7.1 Active customers

**Business meaning:** The number of unique customers who successfully used NovaPay to complete at least one eligible money transfer during the reporting period.

**Calculation:** Distinct count of `customer_id` where the transaction reached `Deposited`, the deposited timestamp falls within the reporting period, and the transaction was not a test, duplicate, fully reversed or fully refunded transaction by the reporting cut-off date.

**Included records:**

- genuine customer accounts;
- eligible transactions that reached `Deposited`;
- transactions deposited during the selected reporting period.

**Excluded records:**

- test customers and transactions;
- duplicate transactions;
- incomplete drafts;
- payment-confirmation-pending and unresolved payment-exception transactions;
- failed and cancelled transactions;
- transactions fully reversed or refunded by the reporting cut-off date.

**Date used:** Deposited timestamp.

**Reporting unit:** Number of unique customers.

**Important assumptions:**

- Transactional activity, rather than login or registration activity, determines whether a customer is active.
- A customer is counted once within the selected period, regardless of how many eligible transactions they completed.
- A customer may be active in several separate months if they complete an eligible transaction in each month.

**Example:** If Customer A completes three eligible transactions and Customer B completes one eligible transaction in August, August has two active customers, not four.

### 7.2 New registrations

**Business meaning:** The number of unique, valid customer accounts created during the reporting period, regardless of whether the customers later complete verification or a transaction.

**Calculation:** Distinct count of `customer_id` where `registration_timestamp` falls within the reporting period.

**Included records:**

- valid customer accounts created during the period;
- customers who have not yet completed verification;
- customers who have not yet completed a transaction.

**Excluded records:**

- test, duplicate and system-generated accounts;
- registration attempts that were started but never successfully submitted;
- records with invalid or unresolvable registration timestamps.

**Date used:** Registration timestamp.

**Reporting unit:** Number of unique customer accounts.

**Important assumptions:**

- Registration occurs only when NovaPay successfully creates the customer account.
- Starting a registration form does not constitute a completed registration.
- Registration does not mean the customer is verified, activated or active.

**Example:** If 120 people start registration but only 100 successfully create accounts, new registrations equal 100. The remaining 20 are incomplete registration attempts.

### 7.3 Currently verified customers

**Business meaning:** The number of unique customers who have at least one approved identity document that remains valid on the reporting date.

**Calculation:** Distinct count of `customer_id` where `verification_status = 'Approved'`, the document has not been superseded and `document_expiry_date` is on or after the reporting date.

**Included records:**

- genuine customer accounts;
- approved identity documents;
- documents that remain valid on the reporting date.

**Excluded records:**

- pending, rejected, expired or superseded documents;
- test and duplicate accounts.

**Date used:** Reporting date for the current population. Verification approval timestamp is used when measuring newly verified customers.

**Reporting unit:** Number of unique customers.

**Important assumptions:**

- A customer with several valid documents is counted once.
- An expired document does not support current verified status unless another valid approved document exists.

### 7.4 Newly activated customers

**Business meaning:** The number of unique customers who completed their first eligible money transfer during the reporting period.

**Calculation:** Distinct count of `customer_id` where the customer's earliest qualifying `Deposited` timestamp falls within the reporting period.

**Included records:** Genuine customers whose first eligible deposited transaction occurred during the period.

**Excluded records:** Test and duplicate customers, and first transactions that were fully reversed or refunded by the reporting cut-off date.

**Date used:** First qualifying deposited transaction timestamp.

**Reporting unit:** Number of unique customers.

**Important assumptions:**

- Verification does not constitute activation.
- A customer can become newly activated only once.

### 7.5 30-day activation rate

**Business meaning:** The percentage of newly registered customers who complete their first eligible money transfer within 30 calendar days of registration.

**Formula:**

```text
Customers activated within 30 days
------------------------------------ × 100
Eligible new registrations
```

**Numerator:** Unique customers in the selected registration cohort whose first qualifying `Deposited` transaction occurred within 30 days of their registration timestamp.

**Denominator:** All valid new registrations in the selected cohort that have had the complete 30-day opportunity to activate.

**Included records:**

- valid registrations;
- mature registration cohorts;
- first deposited transactions occurring within 30 days of registration.

**Excluded records:**

- test and duplicate accounts;
- incomplete registration attempts;
- customers registered too recently to have a complete 30-day observation window;
- invalid event sequences;
- fully reversed or refunded first transactions.

**Dates used:** Registration timestamp assigns the cohort. First qualifying deposited timestamp determines activation.

**Reporting unit:** Percentage.

**Important assumptions:**

- Activation means completing a first eligible transfer, not only becoming verified.
- `Within 30 days` means within 30 multiplied by 24 hours of registration.
- Immature cohorts are excluded rather than incorrectly treated as failures.

**Example:** If 1,000 eligible customers registered in June and 280 completed their first eligible transaction within 30 days, the activation rate is `280 / 1,000 × 100 = 28%`.

### 7.6 Completed remittance volume

**Business meaning:** The total value of eligible transfers successfully delivered to beneficiaries during the reporting period.

**Calculation:** Sum of `send_amount` for eligible transactions that reached `Deposited` during the period.

**Included records:** Genuine, eligible transactions deposited during the selected period.

**Excluded records:** Test, duplicate, incomplete, payment-pending, failed, cancelled, fully refunded and fully reversed transactions.

**Date used:** Deposited timestamp.

**Reporting unit:** GBP and EUR reported separately, plus GBP-equivalent group volume.

**Important assumptions:**

- Amounts in different currencies are never added without conversion to a common reporting currency.
- Historical conversion uses the applicable rate for the transaction or reporting date, not today's exchange rate.
- The group reporting currency is GBP.

### 7.7 Total revenue

**Business meaning:** Revenue earned from eligible completed transfers before operating expenses.

**Calculation:** Transfer-fee revenue plus foreign-exchange margin revenue for eligible deposited transactions.

**Included records:** Eligible deposited transactions with valid fee and exchange-rate information.

**Excluded records:** Test, duplicate, incomplete, failed, cancelled, fully refunded and fully reversed transactions.

**Date used:** Deposited timestamp.

**Reporting unit:** GBP equivalent.

**Important assumptions:**

- Transfer fees and foreign-exchange margin are stored separately before being combined.
- The foreign-exchange margin methodology will be documented and tested before use.
- This is revenue, not profit, because operating and partner costs are not yet deducted.

### 7.8 Incomplete-draft rate

**Business meaning:** The percentage of transaction attempts that customers begin but do not successfully submit.

**Formula:**

```text
Transaction attempts ending as IncompleteDraft
------------------------------------------------ × 100
All eligible transaction attempts started
```

**Included records:** Genuine transaction attempts for which a customer began the transfer journey.

**Excluded records:** Test attempts, duplicate attempt events and submitted transactions experiencing a payment-confirmation issue.

**Date used:** Transaction-attempt start timestamp.

**Reporting unit:** Percentage.

**Important assumptions:**

- A time threshold will define when an unfinished attempt is considered abandoned.
- `IncompleteDraft` is a customer-journey condition and is not a card-acquirer confirmation failure.

### 7.9 Payment-confirmation exception rate

**Business meaning:** The percentage of submitted card-funded transactions for which NovaPay does not receive card-acquirer confirmation within the agreed threshold.

**Formula:**

```text
Submitted card transactions unresolved beyond the threshold
------------------------------------------------------------- × 100
All eligible submitted card-funded transactions
```

**Included records:** Genuine, submitted card-funded transactions requiring acquirer confirmation.

**Excluded records:** Test transactions, duplicate payment attempts, incomplete drafts, and transfers funded through methods that do not use the card-acquirer confirmation process.

**Date used:** Transaction initiation or payment-submission timestamp, according to the agreed operational rule.

**Reporting unit:** Percentage.

**Important assumptions:**

- The operational threshold will be defined before implementation.
- A pending confirmation does not prove that NovaPay received the customer's funds.
- A visible debit on the customer's account may be an authorisation or pending entry rather than a settled payment.
- Unresolved cases move from `PaymentConfirmationPending` to `PaymentException` when the threshold is exceeded.

### 7.10 Transaction failure rate

**Business meaning:** The percentage of eligible submitted transactions that end in a failed status.

**Formula:**

```text
Eligible transactions ending as Failed
----------------------------------------- × 100
All eligible submitted transactions
```

**Included records:** Genuine submitted transactions with a valid terminal or current status.

**Excluded records:** Test transactions, duplicates and incomplete drafts that were never submitted.

**Date used:** Failure timestamp for failed transactions and initiation timestamp for the submitted-transaction population.

**Reporting unit:** Percentage.

**Important assumptions:**

- Cancelled, refunded and payment-confirmation-pending transactions are reported separately from failed transactions.
- The denominator and reporting period will be aligned to prevent comparing unrelated transaction cohorts.

### 7.11 Median end-to-end transaction completion time

**Business meaning:** The typical elapsed time between a customer successfully submitting a transaction and the beneficiary receiving the money.

**Calculation:** For each eligible transaction, subtract `initiated_timestamp` from `deposited_timestamp`, convert the duration to minutes and calculate the median.

**Included records:** Genuine transactions with valid `Initiated` and `Deposited` events that were deposited during the selected period.

**Excluded records:**

- test and duplicate transactions;
- incomplete drafts;
- unresolved payment-pending or payment-exception cases;
- failed and cancelled transactions;
- transactions with missing or invalid event timestamps;
- transactions where the deposited timestamp precedes the initiated timestamp.

**Date used:** Deposited date assigns the transaction to the reporting period.

**Reporting unit:** Minutes.

**Important assumptions:**

- `Initiated` means the customer successfully submitted the transfer.
- `Deposited` means the beneficiary received the funds.
- Elapsed time includes nights, weekends and public holidays.
- The median is the primary measure because a small number of extreme delays can distort the average.
- Average and 90th-percentile completion time will also be reported.

**Example:** If five transactions take 5, 7, 8, 12 and 180 minutes, the median is 8 minutes. The average is 42.4 minutes and is strongly affected by the 180-minute transaction.

### 7.12 90-day retention rate

**Business meaning:** The percentage of newly activated customers who complete at least one additional eligible transaction within 90 days after their first successful transaction.

**Formula:**

```text
Newly activated customers completing a repeat transaction within 90 days
------------------------------------------------------------------------- × 100
All eligible newly activated customers in the mature activation cohort
```

**Included records:** Newly activated customers whose complete 90-day observation period has elapsed.

**Excluded records:** Test and duplicate accounts, immature cohorts, and transactions fully reversed or refunded by the reporting cut-off date.

**Dates used:** First qualifying deposited timestamp defines activation. The next qualifying deposited timestamp determines retention.

**Reporting unit:** Percentage.

**Important assumptions:**

- Retention requires a second eligible transaction; repeated logins alone do not count.
- Customers without a complete 90-day observation window are excluded.
- This definition measures 90-day repeat behaviour, not continuous monthly activity.

## 8. Project scope

### 8.1 Included in the first version

- transfers originating from the United Kingdom and selected European markets;
- GBP and EUR as sending currencies;
- GBP as the common group-reporting currency;
- five African destination countries;
- 24 months of synthetic historical data;
- customer registration and identity-verification journeys;
- beneficiary and referral data;
- transaction and transaction-status histories;
- payment attempts, card-acquirer confirmations and payment-status histories;
- exchange-rate and compliance-review data;
- scheduled batch ingestion and transformation;
- SQL data modelling and data-quality testing;
- Power BI semantic modelling and reporting;
- a later Microsoft Fabric lakehouse and pipeline implementation;
- descriptive customer retention, inactivity and churn analysis.

### 8.2 Possible future extensions

- 12-month forecasting of active customers and transaction volume;
- customer churn-risk modelling;
- near-real-time payment-exception monitoring;
- automated operational alerts;
- partner-level service-level monitoring;
- scenario analysis for exchange-rate and fee changes.

### 8.3 Not included in the first version

- real customer, employer or payment-provider data;
- live production payment processing;
- direct integration with a real card acquirer, bank or payout partner;
- a customer-facing mobile application;
- real-time streaming;
- automated transaction blocking;
- machine-learning fraud detection;
- decisions or interventions affecting real customers.

## 9. Expected source entities

The detailed data model will be designed in a later stage, but the current requirements indicate that the following source entities will be needed:

| Entity | Purpose |
| --- | --- |
| `customers` | Customer account, registration and current account attributes |
| `registration_attempts` | Started, completed and abandoned registration journeys |
| `identity_documents` | Document submission, verification, expiry and renewal events |
| `beneficiaries` | Beneficiary and sender-beneficiary relationship information |
| `referrals` | Referrer, referred prospect and reward journey |
| `transactions` | One record for each submitted remittance instruction |
| `transaction_attempts` | Transfer journeys started before successful submission |
| `transaction_status_history` | Every transaction status transition and its timestamp |
| `payment_attempts` | Attempts to fund submitted transactions |
| `payment_status_history` | Payment authorisation, confirmation, exception, refund and reversal events |
| `exchange_rates` | Market rates, customer rates and applicable timestamps |
| `compliance_reviews` | Review triggers, status, outcome and duration |
| `complaints` | Optional later entity for testing whether service problems affect retention |

## 10. Risks and assumptions

### 10.1 Business-definition risks

- Stakeholders may use different definitions for active, completed, failed, refunded and churned customers or transactions.
- A source-system status may be ambiguous or may represent more than one operational condition.
- Service-level thresholds may not initially be agreed.
- A metric can change materially depending on whether initiation, payment, deposit, settlement or refund date is used.

**Response:** Maintain a documented metric dictionary, identify the owner of each definition and preserve both source and canonical statuses.

### 10.2 Data-quality risks

- Timestamps may be missing, duplicated, out of order or recorded in different time zones.
- A transaction may receive the same status more than once.
- Customer or transaction identifiers may be duplicated.
- Customer payments, acquirer confirmations and transaction outcomes may not reconcile.
- Exchange rates may be missing for some currencies or timestamps.

**Response:** Introduce automated uniqueness, completeness, validity, referential-integrity, chronology and reconciliation tests. Invalid records will be quarantined rather than silently deleted.

### 10.3 Payment-state risks

- A customer-visible debit does not necessarily mean that NovaPay received settled funds.
- Acquirer messages may arrive late or out of sequence.
- A delayed confirmation may later resolve successfully, fail or require a refund.
- The transaction and its funding payment may have different statuses at the same time.

**Response:** Model transactions and payments separately, maintain event histories and define a reporting cut-off time for unresolved events.

### 10.4 Currency risks

- GBP and EUR values cannot be added directly.
- Using today's rate to convert historical transactions would distort past results.
- Customer rates and market rates may have different timestamps or sources.

**Response:** Preserve native amounts and currencies, store the applicable historical rates and calculate a separately identified GBP-equivalent value.

### 10.5 Customer-analysis risks

- Recent registration and activation cohorts may not have had enough time to complete 30-day or 90-day observation periods.
- Churn definitions may differ according to normal customer transfer frequency.
- Operational problems may be associated with churn without necessarily causing it.

**Response:** Exclude immature cohorts, compare alternative churn windows and distinguish association from causation.

### 10.6 Synthetic-data limitations

- Synthetic behaviour will not reproduce every pattern found in real remittance data.
- Forecasting and machine-learning results from synthetic data must not be presented as evidence about real customers.
- Deliberately generated patterns may make analytical findings easier to detect than they would be in production.

**Response:** Clearly label all data and findings as synthetic, document the generation rules and present modelling work as a demonstration of method rather than a real business conclusion.

### 10.7 Security and privacy assumptions

- No real personally identifiable information will be used.
- Generated names, addresses and identifiers will be fictional.
- Credentials, tokens and connection strings will not be committed to GitHub.
- Access-control and row-level-security examples will use fictional roles and users.

## 11. Initial success criteria

The first version of the project will be considered successful when:

1. each priority metric has one documented and testable definition;
2. transactions, payments and their status histories are modelled separately;
3. the two incomplete conditions can be measured independently;
4. the pipeline can be rerun without creating unwanted duplicate records;
5. invalid records are detected and quarantined;
6. raw financial totals reconcile with the curated reporting layer within an agreed tolerance;
7. the Power BI model answers the priority business questions;
8. currency values are reported separately or converted using documented historical rates;
9. customer cohort calculations exclude incomplete observation periods;
10. the repository contains sufficient documentation for another analyst to understand and reproduce the solution.

## 12. Decisions requiring later confirmation

The following decisions will be finalised before implementation of the affected metrics:

1. Which European sending markets will be included?
2. Which five African destination countries and receiving currencies will be used?
3. How long can an unfinished transaction attempt remain open before it becomes `IncompleteDraft`?
4. How long can acquirer confirmation remain pending before it becomes `PaymentException`?
5. What is NovaPay's target end-to-end completion time?
6. Should a deposited transaction that is later partially refunded still count toward customer activity and adjusted volume?
7. What inactivity period should define churn for the principal business KPI?
8. Which exchange-rate timestamp and source should be used for GBP-equivalent reporting?
9. Which public holidays and business-hour rules, if any, should be used for operational service-level calculations?
10. Who is the business owner responsible for approving each metric definition?
