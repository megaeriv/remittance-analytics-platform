"""Validate NovaPay generator configuration and SQL Server connectivity."""

from __future__ import annotations

import json
import os
from pathlib import Path

import pyodbc
from dotenv import load_dotenv


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
    """Load and return the synthetic-data configuration."""

    with CONFIG_FILE.open("r", encoding="utf-8") as file:
        return json.load(file)


def build_connection_string() -> str:
    """Build a trusted local SQL Server connection string."""

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


def main() -> None:
    """Validate files, configuration and database connectivity."""

    if not ENV_FILE.exists():
        raise FileNotFoundError("Missing .env file. Copy .env.example to .env.")
    if not CONFIG_FILE.exists():
        raise FileNotFoundError("Missing config/generator_config.json.")

    load_dotenv(ENV_FILE)
    config = load_generator_config()

    with pyodbc.connect(build_connection_string()) as connection:
        cursor = connection.cursor()
        database_name = cursor.execute("SELECT DB_NAME();").fetchone()[0]
        source_table_count = cursor.execute(
            """
            SELECT COUNT(*)
            FROM sys.tables AS table_object
            INNER JOIN sys.schemas AS schema_object
                ON table_object.schema_id = schema_object.schema_id
            WHERE schema_object.name = 'src';
            """
        ).fetchone()[0]
        process_status_count = cursor.execute(
            "SELECT COUNT(*) FROM ref.process_statuses;"
        ).fetchone()[0]
        transition_count = cursor.execute(
            "SELECT COUNT(*) FROM ref.allowed_status_transitions;"
        ).fetchone()[0]

    print("Environment validation passed")
    print(f"Project: {config['project_name']}")
    print(f"Profile: {config['generation_profile']}")
    print(f"Random seed: {config['random_seed']}")
    print(
        "Period:",
        config["period"]["start_date"],
        "to",
        config["period"]["end_date"],
    )
    print(f"Connected database: {database_name}")
    print(f"Source tables: {source_table_count}")
    print(f"Process statuses: {process_status_count}")
    print(f"Allowed transitions: {transition_count}")


if __name__ == "__main__":
    main()
