"""Generate and load a complete deterministic NovaPay synthetic dataset."""

from __future__ import annotations

import random
import json
import os
from datetime import date, datetime, timedelta
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

import pyodbc
from dotenv import load_dotenv
from faker import Faker


PROJECT_ROOT = Path(__file__).resolve().parents[1]
ENV_FILE = PROJECT_ROOT / ".env"
CONFIG_FILE = PROJECT_ROOT / "config" / "generator_config.json"


def required_environment_value(name: str) -> str:
    """Return a required environment value or raise a clear error."""

    value = os.getenv(name)
    if value is None or not value.strip():
        raise RuntimeError(f"Missing required environment value: {name}")
    return value.strip()


def load_generator_config() -> dict:
    """Load the committed synthetic-data configuration."""

    if not CONFIG_FILE.exists():
        raise FileNotFoundError(
            f"Missing generator configuration: {CONFIG_FILE}"
        )
    with CONFIG_FILE.open("r", encoding="utf-8") as file:
        return json.load(file)


def build_connection_string() -> str:
    """Build the SQL Server connection string from the local .env file."""

    driver = required_environment_value("DB_DRIVER")
    server = required_environment_value("DB_SERVER")
    database = required_environment_value("DB_NAME")
    trusted_connection = required_environment_value("DB_TRUSTED_CONNECTION")
    trust_certificate = required_environment_value(
        "DB_TRUST_SERVER_CERTIFICATE"
    )
    return (
        f"DRIVER={{{driver}}};"
        f"SERVER={server};"
        f"DATABASE={database};"
        f"Trusted_Connection={trusted_connection};"
        f"TrustServerCertificate={trust_certificate};"
    )


SOURCE_TABLES_IN_DELETE_ORDER = [
    "compliance_review_history",
    "compliance_reviews",
    "refund_status_history",
    "refunds",
    "payout_status_history",
    "payout_attempts",
    "payment_status_history",
    "payment_attempts",
    "transaction_status_history",
    "transactions",
    "transaction_attempt_events",
    "transaction_attempts",
    "referrals",
    "beneficiaries",
    "document_verification_history",
    "customer_documents",
    "compliance_requirement_history",
    "customer_compliance_requirements",
    "customers",
    "registration_attempt_events",
    "registration_attempts",
    "exchange_rates",
]

RATES = {
    ("GBP", "NGN"): Decimal("2050.00000000"),
    ("GBP", "GHS"): Decimal("19.50000000"),
    ("GBP", "ZMW"): Decimal("36.00000000"),
    ("GBP", "XAF"): Decimal("780.00000000"),
    ("GBP", "USD"): Decimal("1.28000000"),
    ("EUR", "NGN"): Decimal("1750.00000000"),
    ("EUR", "GHS"): Decimal("16.70000000"),
    ("EUR", "ZMW"): Decimal("30.80000000"),
    ("EUR", "XAF"): Decimal("655.95700000"),
    ("EUR", "USD"): Decimal("1.09000000"),
    ("AUD", "NGN"): Decimal("1050.00000000"),
    ("AUD", "GHS"): Decimal("10.10000000"),
    ("AUD", "ZMW"): Decimal("18.60000000"),
    ("AUD", "XAF"): Decimal("400.00000000"),
    ("AUD", "USD"): Decimal("0.66000000"),
}

GBP_FACTORS = {
    "GBP": Decimal("1.00000000"),
    "EUR": Decimal("0.86000000"),
    "AUD": Decimal("0.52000000"),
}


def money(value: Decimal | float | int | str) -> Decimal:
    """Round a value to the four decimal places used for money."""

    return Decimal(str(value)).quantize(Decimal("0.0001"), ROUND_HALF_UP)


def rate_value(value: Decimal | float | int | str) -> Decimal:
    """Round an exchange rate to eight decimal places."""

    return Decimal(str(value)).quantize(Decimal("0.00000001"), ROUND_HALF_UP)


def random_datetime(
    rng: random.Random,
    start: datetime,
    end: datetime,
) -> datetime:
    """Return a deterministic random datetime in an interval."""

    seconds = max(0, int((end - start).total_seconds()))
    return start + timedelta(seconds=rng.randint(0, seconds))


def synthetic_birth_date(
    rng: random.Random,
    registration_date: date,
) -> date:
    """Return a synthetic birth date for an adult aged 18 to 75."""

    age = rng.randint(18, 75)
    approximate_age_days = age * 365 + rng.randint(0, 364)
    return registration_date - timedelta(days=approximate_age_days)


def ensure_database_is_empty(cursor: pyodbc.Cursor) -> None:
    """Stop rather than overwrite or duplicate existing source data."""

    populated = []
    for table_name in SOURCE_TABLES_IN_DELETE_ORDER:
        count = cursor.execute(
            f"SELECT COUNT(*) FROM src.{table_name};"
        ).fetchone()[0]
        if count:
            populated.append(f"src.{table_name} ({count})")

    if populated:
        raise RuntimeError(
            "Generation stopped because source tables contain data: "
            + ", ".join(populated)
        )


def insert_exchange_rates(
    cursor: pyodbc.Cursor,
    period_start: datetime,
) -> dict[tuple[str, str], int]:
    """Insert one synthetic effective rate for every supported corridor."""

    rate_ids: dict[tuple[str, str], int] = {}
    for exchange_rate_id, ((base, quote), value) in enumerate(
        sorted(RATES.items()),
        start=1,
    ):
        cursor.execute(
            """
            INSERT INTO src.exchange_rates
            (
                exchange_rate_id, base_currency, quote_currency,
                rate_type, rate_value, rate_source,
                effective_from_utc, effective_to_utc, created_at_utc
            )
            VALUES (?, ?, ?, 'Market', ?, 'SyntheticMarketRate', ?, NULL, ?);
            """,
            exchange_rate_id,
            base,
            quote,
            rate_value(value),
            period_start,
            period_start,
        )
        rate_ids[(base, quote)] = exchange_rate_id
    return rate_ids


def add_registration_event(
    cursor: pyodbc.Cursor,
    event_id: int,
    attempt_id: int,
    event_type: str,
    step_name: str,
    step_sequence: int,
    event_time: datetime,
    validation_result: str | None = None,
    error_code: str | None = None,
    source_sequence: int | None = None,
) -> None:
    """Insert one registration event."""

    cursor.execute(
        """
        INSERT INTO src.registration_attempt_events
        (
            registration_attempt_event_id, registration_attempt_id,
            event_type, step_name, step_sequence, event_timestamp_utc,
            validation_result, error_code, source_event_sequence,
            created_at_utc
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """,
        event_id,
        attempt_id,
        event_type,
        step_name,
        step_sequence,
        event_time,
        validation_result,
        error_code,
        source_sequence,
        event_time,
    )


def generate_registrations(
    cursor: pyodbc.Cursor,
    config: dict,
    rng: random.Random,
    fake: Faker,
    period_start: datetime,
    period_end: datetime,
) -> list[dict]:
    """Create registration attempts, customers, events and identity evidence."""

    attempt_count = int(config["scale"]["registration_attempt_count"])
    rules = config.get("registration_rules", {})
    completed_probability = float(rules.get("completed_probability", 0.78))
    abandoned_probability = float(rules.get("abandoned_probability", 0.17))
    failed_probability = float(rules.get("failed_probability", 0.05))
    probabilities = [completed_probability, abandoned_probability, failed_probability]
    if abs(sum(probabilities) - 1.0) > 0.000001:
        raise ValueError("Registration outcome probabilities must total 1.0.")

    channels = rules.get(
        "acquisition_channels",
        ["OrganicSearch", "PaidSocial", "Referral", "Partner", "Direct"],
    )
    devices = rules.get(
        "device_types",
        ["Android", "iOS", "DesktopWeb", "MobileWeb"],
    )
    markets = config["sending_markets"]
    abandonment_minutes = int(config["timing_rules"]["attempt_abandonment_minutes"])

    customers: list[dict] = []
    customer_id = 0
    registration_event_id = 0
    document_id = 0
    document_event_id = 0

    for attempt_id in range(1, attempt_count + 1):
        started_at = random_datetime(rng, period_start, period_end - timedelta(days=1))
        market = rng.choice(markets)
        channel = rng.choice(channels)
        device = rng.choice(devices)
        outcome = rng.choices(
            ["Completed", "Abandoned", "Failed"],
            weights=probabilities,
            k=1,
        )[0]
        session_id = f"REG-{config['random_seed']}-{attempt_id:06d}"

        cursor.execute(
            """
            INSERT INTO src.registration_attempts
            (
                registration_attempt_id, session_id, started_at_utc,
                last_activity_at_utc, completed_at_utc, last_completed_step,
                attempt_status, acquisition_channel, device_type,
                country_code, customer_id, created_at_utc, updated_at_utc
            )
            VALUES (?, ?, ?, ?, NULL, NULL, 'InProgress', ?, ?, ?, NULL, ?, ?);
            """,
            attempt_id,
            session_id,
            started_at,
            started_at,
            channel,
            device,
            market["country_code"],
            started_at,
            started_at,
        )

        registration_event_id += 1
        add_registration_event(
            cursor,
            registration_event_id,
            attempt_id,
            "AttemptStarted",
            "Start",
            1,
            started_at,
            source_sequence=1,
        )

        if outcome == "Completed":
            completed_at = started_at + timedelta(seconds=rng.randint(120, 1080))
            customer_id += 1
            first_name = fake.first_name()
            last_name = fake.last_name()
            marketing_consent = rng.random() < float(
                rules.get("marketing_consent_probability", 0.62)
            )

            cursor.execute(
                """
                INSERT INTO src.customers
                (
                    customer_id, registration_attempt_id,
                    registration_timestamp_utc, first_name, last_name,
                    date_of_birth, country_of_residence_code,
                    preferred_currency, account_status, identity_status,
                    transaction_eligibility_status, acquisition_channel,
                    marketing_consent, created_at_utc, updated_at_utc
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'Active', 'Verified',
                        'Eligible', ?, ?, ?, ?);
                """,
                customer_id,
                attempt_id,
                completed_at,
                first_name,
                last_name,
                synthetic_birth_date(rng, completed_at.date()),
                market["country_code"],
                market["currency"],
                channel,
                marketing_consent,
                completed_at,
                completed_at,
            )

            cursor.execute(
                """
                UPDATE src.registration_attempts
                SET last_activity_at_utc = ?, completed_at_utc = ?,
                    last_completed_step = 'Completed',
                    attempt_status = 'Completed', customer_id = ?,
                    updated_at_utc = ?
                WHERE registration_attempt_id = ?;
                """,
                completed_at,
                completed_at,
                customer_id,
                completed_at,
                attempt_id,
            )

            for sequence, (event_type, step_name, fraction) in enumerate(
                [
                    ("StepViewed", "PersonalDetails", 0.20),
                    ("StepCompleted", "PersonalDetails", 0.55),
                    ("RegistrationSubmitted", "Review", 0.85),
                    ("AccountCreated", "Completed", 1.00),
                ],
                start=2,
            ):
                event_time = started_at + (completed_at - started_at) * fraction
                registration_event_id += 1
                add_registration_event(
                    cursor,
                    registration_event_id,
                    attempt_id,
                    event_type,
                    step_name,
                    sequence,
                    event_time,
                    "Passed",
                    source_sequence=sequence,
                )

            document_id += 1
            document_event_id += 1
            submitted_at = completed_at + timedelta(minutes=rng.randint(1, 60))
            approved_at = submitted_at + timedelta(minutes=rng.randint(1, 240))
            issue_date = completed_at.date() - timedelta(days=rng.randint(365, 2500))
            expiry_date = completed_at.date() + timedelta(days=rng.randint(365, 2500))
            cursor.execute(
                """
                INSERT INTO src.customer_documents
                (
                    document_id, customer_id, compliance_requirement_id,
                    document_category, document_type, issuing_country_code,
                    document_reference_token, submitted_at_utc,
                    document_issue_date, document_expiry_date,
                    current_verification_status, current_status_at_utc,
                    is_current_document, superseded_by_document_id,
                    created_at_utc, updated_at_utc
                )
                VALUES (?, ?, NULL, 'Identity', 'Passport', ?, ?, ?, ?, ?,
                        'Approved', ?, 1, NULL, ?, ?);
                """,
                document_id,
                customer_id,
                market["country_code"],
                f"DOC-{document_id:08d}",
                submitted_at,
                issue_date,
                expiry_date,
                approved_at,
                submitted_at,
                approved_at,
            )
            cursor.execute(
                """
                INSERT INTO src.document_verification_history
                (
                    document_verification_event_id, document_id,
                    verification_status, event_timestamp_utc, review_method,
                    reason_code, reviewer_role, source_system,
                    source_event_sequence, created_at_utc
                )
                VALUES (?, ?, 'Submitted', ?, NULL, NULL, NULL,
                        'NovaPayApp', 1, ?);
                """,
                document_event_id,
                document_id,
                submitted_at,
                submitted_at,
            )
            document_event_id += 1
            cursor.execute(
                """
                INSERT INTO src.document_verification_history
                (
                    document_verification_event_id, document_id,
                    verification_status, event_timestamp_utc, review_method,
                    reason_code, reviewer_role, source_system,
                    source_event_sequence, created_at_utc
                )
                VALUES (?, ?, 'Approved', ?, 'Automated', NULL, NULL,
                        'SyntheticVerificationProvider', 2, ?);
                """,
                document_event_id,
                document_id,
                approved_at,
                approved_at,
            )

            customers.append(
                {
                    "customer_id": customer_id,
                    "registration_at": completed_at,
                    "country_code": market["country_code"],
                    "currency": market["currency"],
                    "document_id": document_id,
                }
            )

        elif outcome == "Abandoned":
            last_activity = started_at + timedelta(minutes=rng.randint(1, 12))
            abandoned_at = last_activity + timedelta(minutes=abandonment_minutes)
            cursor.execute(
                """
                UPDATE src.registration_attempts
                SET last_activity_at_utc = ?, last_completed_step = 'PersonalDetails',
                    attempt_status = 'Abandoned', updated_at_utc = ?
                WHERE registration_attempt_id = ?;
                """,
                last_activity,
                abandoned_at,
                attempt_id,
            )
            registration_event_id += 1
            add_registration_event(
                cursor,
                registration_event_id,
                attempt_id,
                "AttemptAbandoned",
                "PersonalDetails",
                2,
                abandoned_at,
                source_sequence=2,
            )
        else:
            failed_at = started_at + timedelta(seconds=rng.randint(30, 480))
            cursor.execute(
                """
                UPDATE src.registration_attempts
                SET last_activity_at_utc = ?, last_completed_step = 'PersonalDetails',
                    attempt_status = 'Failed', updated_at_utc = ?
                WHERE registration_attempt_id = ?;
                """,
                failed_at,
                failed_at,
                attempt_id,
            )
            registration_event_id += 1
            add_registration_event(
                cursor,
                registration_event_id,
                attempt_id,
                "ValidationFailed",
                "PersonalDetails",
                2,
                failed_at,
                "Failed",
                "REG_VALIDATION",
                2,
            )

    return customers


def generate_beneficiaries_and_referrals(
    cursor: pyodbc.Cursor,
    customers: list[dict],
    rng: random.Random,
    fake: Faker,
) -> dict[int, dict]:
    """Create one beneficiary per customer and a subset of referrals."""

    destination_options = [
        ("NG", "NGN"),
        ("GH", "GHS"),
        ("ZM", "ZMW"),
        ("CM", "XAF"),
        ("ZW", "USD"),
    ]
    beneficiaries: dict[int, dict] = {}

    for beneficiary_id, customer in enumerate(customers, start=1):
        destination_country, receive_currency = rng.choice(destination_options)
        collection_method = rng.choice(["Bank", "MobileWallet", "Cash"])
        cursor.execute(
            """
            INSERT INTO src.beneficiaries
            (
                beneficiary_id, customer_id, first_name, last_name,
                destination_country_code, receive_currency,
                collection_method, beneficiary_status,
                created_at_utc, updated_at_utc
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, 'Active', ?, ?);
            """,
            beneficiary_id,
            customer["customer_id"],
            fake.first_name(),
            fake.last_name(),
            destination_country,
            receive_currency,
            collection_method,
            customer["registration_at"],
            customer["registration_at"],
        )
        beneficiaries[customer["customer_id"]] = {
            "beneficiary_id": beneficiary_id,
            "country_code": destination_country,
            "currency": receive_currency,
            "collection_method": collection_method,
        }

    ordered_customers = sorted(customers, key=lambda row: row["registration_at"])
    referral_id = 0
    for position in range(0, len(ordered_customers) - 1, 4):
        referrer = ordered_customers[position]
        referred = ordered_customers[position + 1]
        if referrer["registration_at"] >= referred["registration_at"]:
            continue
        referral_id += 1
        interval = referred["registration_at"] - referrer["registration_at"]
        invited_at = referrer["registration_at"] + interval / 2
        cursor.execute(
            """
            INSERT INTO src.referrals
            (
                referral_id, referrer_customer_id, referral_code,
                referred_contact_token, referred_customer_id,
                referral_status, invited_at_utc, registered_at_utc,
                activated_at_utc, reward_status
            )
            VALUES (?, ?, ?, ?, ?, 'Activated', ?, ?, ?, 'Pending');
            """,
            referral_id,
            referrer["customer_id"],
            f"REF-{referral_id:06d}",
            f"CONTACT-{referral_id:06d}",
            referred["customer_id"],
            invited_at,
            referred["registration_at"],
            referred["registration_at"] + timedelta(days=1),
        )

    return beneficiaries


def add_transaction_history(
    cursor: pyodbc.Cursor,
    history_id: int,
    transaction_id: int,
    status: str,
    event_time: datetime,
    sequence: int,
    reason_code: str | None = None,
) -> None:
    """Insert one transaction status-history row."""

    cursor.execute(
        """
        INSERT INTO src.transaction_status_history
        (
            transaction_status_event_id, transaction_id, source_status,
            canonical_status, event_timestamp_utc, reason_code,
            source_system, source_event_sequence, created_at_utc
        )
        VALUES (?, ?, ?, ?, ?, ?, 'NovaPayCore', ?, ?);
        """,
        history_id,
        transaction_id,
        status,
        status,
        event_time,
        reason_code,
        sequence,
        event_time,
    )


def generate_money_movement(
    cursor: pyodbc.Cursor,
    config: dict,
    customers: list[dict],
    beneficiaries: dict[int, dict],
    rate_ids: dict[tuple[str, str], int],
    rng: random.Random,
    period_end: datetime,
) -> None:
    """Create attempts, transactions, payments, payouts and exceptions."""

    transaction_attempt_id = 0
    transaction_attempt_event_id = 0
    transaction_id = 0
    transaction_history_id = 0
    payment_attempt_id = 0
    payment_history_id = 0
    payout_attempt_id = 0
    payout_history_id = 0
    refund_id = 0
    refund_history_id = 0
    requirement_id = 0
    requirement_event_id = 0
    document_id = cursor.execute(
        "SELECT COALESCE(MAX(document_id), 0) FROM src.customer_documents;"
    ).fetchone()[0]
    document_event_id = cursor.execute(
        "SELECT COALESCE(MAX(document_verification_event_id), 0) "
        "FROM src.document_verification_history;"
    ).fetchone()[0]
    compliance_review_id = 0
    compliance_review_event_id = 0

    for customer in customers:
        beneficiary = beneficiaries[customer["customer_id"]]
        attempts_for_customer = 2

        for attempt_number in range(attempts_for_customer):
            transaction_attempt_id += 1
            started_at = customer["registration_at"] + timedelta(
                days=rng.randint(1, 120), minutes=rng.randint(0, 600)
            )
            if started_at > period_end:
                started_at = period_end - timedelta(days=rng.randint(1, 30))

            is_incomplete = attempt_number == 1 and customer["customer_id"] % 5 == 0
            send_currency = customer["currency"]
            receive_currency = beneficiary["currency"]
            quoted_rate_id = rate_ids[(send_currency, receive_currency)]
            base_amount = money(rng.randint(50, 2500))

            cursor.execute(
                """
                INSERT INTO src.transaction_attempts
                (
                    transaction_attempt_id, customer_id, started_at_utc,
                    last_activity_at_utc, last_completed_step, send_amount,
                    send_currency, destination_country_code, beneficiary_id,
                    collection_method, quoted_exchange_rate_id,
                    attempt_status, transaction_id, submitted_at_utc,
                    created_at_utc, updated_at_utc
                )
                VALUES (?, ?, ?, ?, 'Amount', ?, ?, ?, ?, ?, ?,
                        'InProgress', NULL, NULL, ?, ?);
                """,
                transaction_attempt_id,
                customer["customer_id"],
                started_at,
                started_at,
                base_amount,
                send_currency,
                beneficiary["country_code"],
                beneficiary["beneficiary_id"],
                beneficiary["collection_method"],
                quoted_rate_id,
                started_at,
                started_at,
            )

            transaction_attempt_event_id += 1
            cursor.execute(
                """
                INSERT INTO src.transaction_attempt_events
                (
                    transaction_attempt_event_id, transaction_attempt_id,
                    event_type, step_name, step_sequence,
                    event_timestamp_utc, validation_result, error_code,
                    created_at_utc
                )
                VALUES (?, ?, 'AttemptStarted', 'Start', 1, ?, NULL, NULL, ?);
                """,
                transaction_attempt_event_id,
                transaction_attempt_id,
                started_at,
                started_at,
            )

            if is_incomplete:
                last_activity = started_at + timedelta(minutes=rng.randint(1, 12))
                cursor.execute(
                    """
                    UPDATE src.transaction_attempts
                    SET last_activity_at_utc = ?, last_completed_step = 'Beneficiary',
                        attempt_status = 'IncompleteDraft', updated_at_utc = ?
                    WHERE transaction_attempt_id = ?;
                    """,
                    last_activity,
                    last_activity + timedelta(minutes=20),
                    transaction_attempt_id,
                )
                transaction_attempt_event_id += 1
                cursor.execute(
                    """
                    INSERT INTO src.transaction_attempt_events
                    (
                        transaction_attempt_event_id, transaction_attempt_id,
                        event_type, step_name, step_sequence,
                        event_timestamp_utc, validation_result, error_code,
                        created_at_utc
                    )
                    VALUES (?, ?, 'AttemptAbandoned', 'Beneficiary', 2, ?, NULL, NULL, ?);
                    """,
                    transaction_attempt_event_id,
                    transaction_attempt_id,
                    last_activity + timedelta(minutes=20),
                    last_activity + timedelta(minutes=20),
                )
                continue

            transaction_id += 1
            submitted_at = started_at + timedelta(minutes=rng.randint(1, 8))
            scenario = transaction_id % 10
            if scenario == 9:
                gbp_equivalent = money("10500.00")
                send_amount = money(gbp_equivalent / GBP_FACTORS[send_currency])
            else:
                send_amount = base_amount
                gbp_equivalent = money(send_amount * GBP_FACTORS[send_currency])

            customer_rate = rate_value(RATES[(send_currency, receive_currency)] * Decimal("0.985"))
            receive_amount = money(send_amount * customer_rate)
            fee = money(max(Decimal("1.99"), send_amount * Decimal("0.01")))
            scenario_status = {
                0: "PaymentException",
                7: "Failed",
                8: "Refunded",
                9: "ComplianceHold",
            }.get(scenario, "Deposited")
            deposited_at = (
                submitted_at + timedelta(minutes=rng.randint(1, 5))
                if scenario_status == "Deposited"
                else None
            )

            cursor.execute(
                """
                INSERT INTO src.transactions
                (
                    transaction_id, transaction_attempt_id, customer_id,
                    beneficiary_id, send_amount, send_currency,
                    send_amount_gbp_equivalent, receive_amount,
                    receive_currency, transfer_fee, customer_exchange_rate,
                    market_exchange_rate_id, collection_method,
                    current_transaction_status, initiated_at_utc,
                    deposited_at_utc, created_at_utc, updated_at_utc
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """,
                transaction_id,
                transaction_attempt_id,
                customer["customer_id"],
                beneficiary["beneficiary_id"],
                send_amount,
                send_currency,
                gbp_equivalent,
                receive_amount,
                receive_currency,
                fee,
                customer_rate,
                quoted_rate_id,
                beneficiary["collection_method"],
                scenario_status,
                submitted_at,
                deposited_at,
                submitted_at,
                deposited_at or submitted_at,
            )

            cursor.execute(
                """
                UPDATE src.transaction_attempts
                SET last_activity_at_utc = ?, last_completed_step = 'Submitted',
                    attempt_status = 'Submitted', transaction_id = ?,
                    submitted_at_utc = ?, updated_at_utc = ?
                WHERE transaction_attempt_id = ?;
                """,
                submitted_at,
                transaction_id,
                submitted_at,
                submitted_at,
                transaction_attempt_id,
            )

            transaction_attempt_event_id += 1
            cursor.execute(
                """
                INSERT INTO src.transaction_attempt_events
                (
                    transaction_attempt_event_id, transaction_attempt_id,
                    event_type, step_name, step_sequence,
                    event_timestamp_utc, validation_result, error_code,
                    created_at_utc
                )
                VALUES (?, ?, 'TransactionSubmitted', 'Submitted', 2, ?,
                        'Passed', NULL, ?);
                """,
                transaction_attempt_event_id,
                transaction_attempt_id,
                submitted_at,
                submitted_at,
            )

            payment_attempt_id += 1
            payment_submitted = submitted_at + timedelta(seconds=10)
            payment_amount = money(send_amount + fee)

            if scenario == 7:
                payment_status = "Declined"
                payment_events = [
                    ("Submitted", payment_submitted),
                    ("Declined", payment_submitted + timedelta(seconds=20)),
                ]
                transaction_events = [
                    ("Initiated", submitted_at),
                    ("AwaitingPayment", submitted_at + timedelta(seconds=5)),
                    ("Failed", payment_submitted + timedelta(seconds=20)),
                ]
            elif scenario == 0:
                payment_status = "Failed"
                payment_events = [
                    ("Submitted", payment_submitted),
                    ("ConfirmationPending", payment_submitted + timedelta(minutes=2)),
                    ("Failed", payment_submitted + timedelta(hours=24, seconds=1)),
                ]
                transaction_events = [
                    ("Initiated", submitted_at),
                    ("AwaitingPayment", submitted_at + timedelta(seconds=5)),
                    ("PaymentConfirmationPending", payment_submitted + timedelta(minutes=2)),
                    ("PaymentException", payment_submitted + timedelta(hours=24, seconds=1)),
                ]
            else:
                payment_status = "Confirmed"
                payment_confirmed = payment_submitted + timedelta(seconds=rng.randint(5, 25))
                payment_events = [
                    ("Submitted", payment_submitted),
                    ("Confirmed", payment_confirmed),
                ]
                transaction_events = [
                    ("Initiated", submitted_at),
                    ("AwaitingPayment", submitted_at + timedelta(seconds=5)),
                    ("PaymentConfirmed", payment_confirmed),
                ]
                if scenario_status == "Deposited":
                    transaction_events.extend(
                        [
                            ("Processing", payment_confirmed + timedelta(seconds=10)),
                            ("Deposited", deposited_at),
                        ]
                    )
                elif scenario == 8:
                    transaction_events.extend(
                        [
                            ("Cancelled", payment_confirmed + timedelta(seconds=15)),
                            ("RefundPending", payment_confirmed + timedelta(minutes=1)),
                            ("Refunded", payment_confirmed + timedelta(days=3)),
                        ]
                    )
                elif scenario == 9:
                    transaction_events.append(
                        ("ComplianceHold", payment_confirmed + timedelta(seconds=15))
                    )

            confirmed_at = next(
                (event_time for status, event_time in payment_events if status == "Confirmed"),
                None,
            )
            cursor.execute(
                """
                INSERT INTO src.payment_attempts
                (
                    payment_attempt_id, transaction_id, payment_method,
                    payment_provider, payment_amount, payment_currency,
                    provider_reference_token, current_payment_status,
                    submitted_at_utc, confirmed_at_utc,
                    created_at_utc, updated_at_utc
                )
                VALUES (?, ?, ?, 'SyntheticAcquirer', ?, ?, ?, ?, ?, ?, ?, ?);
                """,
                payment_attempt_id,
                transaction_id,
                rng.choice(["Card", "ApplePay", "BankTransfer"]),
                payment_amount,
                send_currency,
                f"PAY-{payment_attempt_id:08d}",
                payment_status,
                payment_submitted,
                confirmed_at,
                payment_submitted,
                payment_events[-1][1],
            )
            for payment_status_event, payment_event_time in payment_events:
                payment_history_id += 1
                cursor.execute(
                    """
                    INSERT INTO src.payment_status_history
                    (
                        payment_status_event_id, payment_attempt_id,
                        source_status, canonical_status,
                        event_timestamp_utc, reason_code,
                        source_system, created_at_utc
                    )
                    VALUES (?, ?, ?, ?, ?, ?, 'SyntheticAcquirer', ?);
                    """,
                    payment_history_id,
                    payment_attempt_id,
                    payment_status_event,
                    payment_status_event,
                    payment_event_time,
                    "PAYMENT_DECLINED" if payment_status_event == "Declined" else None,
                    payment_event_time,
                )

            for sequence, (status, status_time) in enumerate(transaction_events, start=1):
                transaction_history_id += 1
                add_transaction_history(
                    cursor,
                    transaction_history_id,
                    transaction_id,
                    status,
                    status_time,
                    sequence,
                    "PAYMENT_FAILURE" if status == "Failed" else None,
                )

            if scenario_status == "Deposited":
                payout_attempt_id += 1
                payout_submitted = confirmed_at + timedelta(seconds=10)
                payout_events = [
                    ("Submitted", payout_submitted),
                    ("Accepted", payout_submitted + timedelta(seconds=10)),
                    ("Processing", payout_submitted + timedelta(seconds=20)),
                    ("Deposited", deposited_at),
                ]
                cursor.execute(
                    """
                    INSERT INTO src.payout_attempts
                    (
                        payout_attempt_id, transaction_id, payout_partner,
                        collection_method, payout_amount, payout_currency,
                        partner_reference_token, current_payout_status,
                        submitted_at_utc, completed_at_utc,
                        created_at_utc, updated_at_utc
                    )
                    VALUES (?, ?, 'SyntheticPayoutPartner', ?, ?, ?, ?,
                            'Deposited', ?, ?, ?, ?);
                    """,
                    payout_attempt_id,
                    transaction_id,
                    beneficiary["collection_method"],
                    receive_amount,
                    receive_currency,
                    f"PAYOUT-{payout_attempt_id:08d}",
                    payout_submitted,
                    deposited_at,
                    payout_submitted,
                    deposited_at,
                )
                for payout_status, payout_time in payout_events:
                    payout_history_id += 1
                    cursor.execute(
                        """
                        INSERT INTO src.payout_status_history
                        (
                            payout_status_event_id, payout_attempt_id,
                            source_status, canonical_status,
                            event_timestamp_utc, reason_code,
                            source_system, created_at_utc
                        )
                        VALUES (?, ?, ?, ?, ?, NULL,
                                'SyntheticPayoutPartner', ?);
                        """,
                        payout_history_id,
                        payout_attempt_id,
                        payout_status,
                        payout_status,
                        payout_time,
                        payout_time,
                    )

            if scenario == 8:
                refund_id += 1
                requested = confirmed_at + timedelta(minutes=1)
                completed = confirmed_at + timedelta(days=3)
                cursor.execute(
                    """
                    INSERT INTO src.refunds
                    (
                        refund_id, transaction_id, payment_attempt_id,
                        refund_type, refund_amount, refund_currency,
                        refund_reason_code, current_refund_status,
                        requested_at_utc, completed_at_utc,
                        created_at_utc, updated_at_utc
                    )
                    VALUES (?, ?, ?, 'Full', ?, ?, 'CANCELLED_AFTER_PAYMENT',
                            'Completed', ?, ?, ?, ?);
                    """,
                    refund_id,
                    transaction_id,
                    payment_attempt_id,
                    payment_amount,
                    send_currency,
                    requested,
                    completed,
                    requested,
                    completed,
                )
                for refund_status, refund_time in [
                    ("Requested", requested),
                    ("Approved", requested + timedelta(minutes=5)),
                    ("Submitted", requested + timedelta(minutes=10)),
                    ("Processing", requested + timedelta(hours=1)),
                    ("Completed", completed),
                ]:
                    refund_history_id += 1
                    cursor.execute(
                        """
                        INSERT INTO src.refund_status_history
                        (
                            refund_status_event_id, refund_id,
                            refund_status, event_timestamp_utc,
                            reason_code, created_at_utc
                        )
                        VALUES (?, ?, ?, ?, NULL, ?);
                        """,
                        refund_history_id,
                        refund_id,
                        refund_status,
                        refund_time,
                        refund_time,
                    )

            if scenario == 9:
                cursor.execute(
                    """
                    UPDATE src.customers
                    SET account_status = 'Restricted',
                        transaction_eligibility_status = 'RestrictedPendingReview',
                        updated_at_utc = ?
                    WHERE customer_id = ?;
                    """,
                    transaction_events[-1][1],
                    customer["customer_id"],
                )

                for requirement_type in ("ProofOfAddress", "SourceOfFunds"):
                    requirement_id += 1
                    triggered_at = transaction_events[-1][1]
                    cursor.execute(
                        """
                        INSERT INTO src.customer_compliance_requirements
                        (
                            compliance_requirement_id, customer_id,
                            requirement_type, trigger_type,
                            triggered_transaction_id, threshold_amount_gbp,
                            qualifying_volume_gbp, current_requirement_status,
                            triggered_at_utc, satisfied_at_utc, expires_on,
                            created_at_utc, updated_at_utc
                        )
                        VALUES (?, ?, ?, 'CumulativeVolumeThreshold', ?,
                                10000.0000, ?, 'UnderReview', ?, NULL, NULL, ?, ?);
                        """,
                        requirement_id,
                        customer["customer_id"],
                        requirement_type,
                        transaction_id,
                        gbp_equivalent,
                        triggered_at,
                        triggered_at,
                        triggered_at,
                    )
                    for sequence, (status, offset) in enumerate(
                        [
                            ("Required", timedelta(seconds=0)),
                            ("AwaitingDocument", timedelta(minutes=1)),
                            ("Submitted", timedelta(days=1)),
                            ("UnderReview", timedelta(days=1, minutes=10)),
                        ],
                        start=1,
                    ):
                        requirement_event_id += 1
                        event_time = triggered_at + offset
                        cursor.execute(
                            """
                            INSERT INTO src.compliance_requirement_history
                            (
                                requirement_event_id, compliance_requirement_id,
                                requirement_status, event_timestamp_utc,
                                reason_code, reviewer_role, source_system,
                                source_event_sequence, created_at_utc
                            )
                            VALUES (?, ?, ?, ?, NULL, ?, 'NovaPayCompliance', ?, ?);
                            """,
                            requirement_event_id,
                            requirement_id,
                            status,
                            event_time,
                            "ComplianceAnalyst" if status == "UnderReview" else None,
                            sequence,
                            event_time,
                        )

                    document_id += 1
                    document_event_id += 1
                    document_submitted = triggered_at + timedelta(days=1)
                    category = requirement_type
                    doc_type = "BankStatement" if category == "ProofOfAddress" else "Payslip"
                    cursor.execute(
                        """
                        INSERT INTO src.customer_documents
                        (
                            document_id, customer_id, compliance_requirement_id,
                            document_category, document_type,
                            issuing_country_code, document_reference_token,
                            submitted_at_utc, document_issue_date,
                            document_expiry_date, current_verification_status,
                            current_status_at_utc, is_current_document,
                            superseded_by_document_id, created_at_utc, updated_at_utc
                        )
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL,
                                'ManualReview', ?, 1, NULL, ?, ?);
                        """,
                        document_id,
                        customer["customer_id"],
                        requirement_id,
                        category,
                        doc_type,
                        customer["country_code"],
                        f"DOC-{document_id:08d}",
                        document_submitted,
                        document_submitted.date() - timedelta(days=30),
                        document_submitted + timedelta(minutes=10),
                        document_submitted,
                        document_submitted + timedelta(minutes=10),
                    )
                    cursor.execute(
                        """
                        INSERT INTO src.document_verification_history
                        (
                            document_verification_event_id, document_id,
                            verification_status, event_timestamp_utc,
                            review_method, reason_code, reviewer_role,
                            source_system, source_event_sequence, created_at_utc
                        )
                        VALUES (?, ?, 'Submitted', ?, NULL, NULL, NULL,
                                'NovaPayApp', 1, ?);
                        """,
                        document_event_id,
                        document_id,
                        document_submitted,
                        document_submitted,
                    )
                    document_event_id += 1
                    cursor.execute(
                        """
                        INSERT INTO src.document_verification_history
                        (
                            document_verification_event_id, document_id,
                            verification_status, event_timestamp_utc,
                            review_method, reason_code, reviewer_role,
                            source_system, source_event_sequence, created_at_utc
                        )
                        VALUES (?, ?, 'ManualReview', ?, 'Manual', NULL,
                                'ComplianceAnalyst', 'NovaPayCompliance', 2, ?);
                        """,
                        document_event_id,
                        document_id,
                        document_submitted + timedelta(minutes=10),
                        document_submitted + timedelta(minutes=10),
                    )

                compliance_review_id += 1
                review_opened = transaction_events[-1][1]
                cursor.execute(
                    """
                    INSERT INTO src.compliance_reviews
                    (
                        compliance_review_id, customer_id, transaction_id,
                        review_type, trigger_rule_code, risk_level,
                        current_review_status, review_outcome,
                        opened_at_utc, closed_at_utc,
                        created_at_utc, updated_at_utc
                    )
                    VALUES (?, ?, ?, 'Transaction', 'ROLLING_12M_10000',
                            'Medium', 'UnderReview', NULL, ?, NULL, ?, ?);
                    """,
                    compliance_review_id,
                    customer["customer_id"],
                    transaction_id,
                    review_opened,
                    review_opened,
                    review_opened,
                )
                for status, offset in [
                    ("Opened", timedelta(seconds=0)),
                    ("Assigned", timedelta(minutes=5)),
                    ("UnderReview", timedelta(minutes=10)),
                ]:
                    compliance_review_event_id += 1
                    event_time = review_opened + offset
                    cursor.execute(
                        """
                        INSERT INTO src.compliance_review_history
                        (
                            compliance_review_event_id, compliance_review_id,
                            review_status, event_timestamp_utc,
                            reason_code, reviewer_role, created_at_utc
                        )
                        VALUES (?, ?, ?, ?, NULL, 'ComplianceAnalyst', ?);
                        """,
                        compliance_review_event_id,
                        compliance_review_id,
                        status,
                        event_time,
                        event_time,
                    )


def validate_loaded_data(cursor: pyodbc.Cursor) -> None:
    """Raise an error if essential cross-table controls fail."""

    checks = {
        "source tables populated": """
            SELECT COUNT(*)
            FROM sys.tables AS t
            INNER JOIN sys.schemas AS s ON t.schema_id = s.schema_id
            WHERE s.name = 'src'
              AND NOT EXISTS
                  (SELECT 1 WHERE OBJECT_ID('src.' + t.name) IS NULL);
        """,
        "completed attempts without customers": """
            SELECT COUNT(*) FROM src.registration_attempts
            WHERE attempt_status = 'Completed' AND customer_id IS NULL;
        """,
        "incomplete attempts with transactions": """
            SELECT COUNT(*) FROM src.transaction_attempts
            WHERE attempt_status = 'IncompleteDraft' AND transaction_id IS NOT NULL;
        """,
        "deposits without payout deposit": """
            SELECT COUNT(*)
            FROM src.transactions AS t
            WHERE t.current_transaction_status = 'Deposited'
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM src.payout_attempts AS p
                  WHERE p.transaction_id = t.transaction_id
                    AND p.current_payout_status = 'Deposited'
              );
        """,
    }

    expected_zero = {
        "completed attempts without customers",
        "incomplete attempts with transactions",
        "deposits without payout deposit",
    }

    for name, query in checks.items():
        value = cursor.execute(query).fetchone()[0]
        if name in expected_zero and value != 0:
            raise RuntimeError(f"Validation failed: {name} = {value}")


def print_summary(cursor: pyodbc.Cursor) -> None:
    """Print a compact row-count summary for every source table."""

    print("Complete NovaPay generation succeeded")
    for table_name in reversed(SOURCE_TABLES_IN_DELETE_ORDER):
        count = cursor.execute(
            f"SELECT COUNT(*) FROM src.{table_name};"
        ).fetchone()[0]
        print(f"src.{table_name}: {count}")

    statuses = cursor.execute(
        """
        SELECT current_transaction_status, COUNT(*)
        FROM src.transactions
        GROUP BY current_transaction_status
        ORDER BY current_transaction_status;
        """
    ).fetchall()
    print("Transaction outcomes:")
    for status, count in statuses:
        print(f"  {status}: {count}")


def main() -> None:
    """Generate and load all NovaPay source entities once."""

    load_dotenv(ENV_FILE)
    config = load_generator_config()
    seed = int(config["random_seed"])
    rng = random.Random(seed)
    Faker.seed(seed)
    fake = Faker("en_GB")
    fake.seed_instance(seed)
    period_start = datetime.fromisoformat(config["period"]["start_date"])
    period_end = datetime.fromisoformat(config["period"]["end_date"]).replace(
        hour=23,
        minute=59,
        second=59,
    )

    connection = pyodbc.connect(build_connection_string(), autocommit=False)
    try:
        cursor = connection.cursor()
        ensure_database_is_empty(cursor)
        rate_ids = insert_exchange_rates(cursor, period_start)
        customers = generate_registrations(
            cursor,
            config,
            rng,
            fake,
            period_start,
            period_end,
        )
        beneficiaries = generate_beneficiaries_and_referrals(
            cursor,
            customers,
            rng,
            fake,
        )
        generate_money_movement(
            cursor,
            config,
            customers,
            beneficiaries,
            rate_ids,
            rng,
            period_end,
        )
        validate_loaded_data(cursor)
        connection.commit()
        print_summary(cursor)
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


if __name__ == "__main__":
    main()
