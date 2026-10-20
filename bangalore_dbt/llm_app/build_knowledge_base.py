"""
Export selected Snowflake analytical marts into a local JSON
knowledge base for the Bengaluru Mobility RAG assistant.
"""

import json
import os
import sys
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path
from typing import Any

import snowflake.connector
from dotenv import load_dotenv


BASE_DIR = Path(__file__).resolve().parent
ENV_FILE = BASE_DIR / ".env"
DATA_DIR = BASE_DIR / "data"
OUTPUT_FILE = DATA_DIR / "knowledge_base.json"


KNOWLEDGE_TABLES = [
    "MART_CITY_KPI_CATALOG",
    "MART_REPORT_FINDINGS",
    "MART_WEATHER_AIR_QUALITY_SUMMARY",
    "MART_PUBLIC_TRANSPORT_VEHICLE_PRESSURE_YEARLY",
    "MART_METRO_STATION_SUMMARY",
    "MART_ROAD_SAFETY_CITY_YEARLY",
    "MART_VEHICLE_TYPE_YEARLY",
]


def require_environment_variable(name: str) -> str:
    """Return a required environment variable."""

    value = os.getenv(name, "").strip()

    if not value:
        raise ValueError(
            f"Required environment variable {name} is missing."
        )

    return value


def serialise_value(value: Any) -> Any:
    """Convert Snowflake values into JSON-compatible values."""

    if value is None:
        return None

    if isinstance(value, Decimal):
        return float(value)

    if isinstance(value, (datetime, date)):
        return value.isoformat()

    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")

    return value


def format_value(value: Any) -> str:
    """Convert a value into human-readable text."""

    if value is None:
        return "not reported"

    if isinstance(value, bool):
        return "yes" if value else "no"

    return str(value)


def create_document(
    table_name: str,
    row_number: int,
    columns: list[str],
    row: tuple[Any, ...],
) -> dict[str, Any]:
    """Convert one Snowflake row into one RAG document."""

    record = {
        column: serialise_value(value)
        for column, value in zip(columns, row)
    }

    readable_fields = []

    for column, value in record.items():
        readable_name = column.replace("_", " ").title()
        readable_value = format_value(value)

        readable_fields.append(
            f"{readable_name}: {readable_value}"
        )

    content = (
        f"Source analytical model: {table_name}. "
        + ". ".join(readable_fields)
        + "."
    )

    return {
        "document_id": (
            f"{table_name.lower()}_{row_number:04d}"
        ),
        "source_model": table_name,
        "row_number": row_number,
        "content": content,
        "record": record,
    }


def connect_to_snowflake():
    """Create the Snowflake connection."""

    return snowflake.connector.connect(
        account=require_environment_variable(
            "SNOWFLAKE_ACCOUNT"
        ),
        user=require_environment_variable(
            "SNOWFLAKE_USER"
        ),
        password=require_environment_variable(
            "SNOWFLAKE_PASSWORD"
        ),
        warehouse=require_environment_variable(
            "SNOWFLAKE_WAREHOUSE"
        ),
        database=require_environment_variable(
            "SNOWFLAKE_DATABASE"
        ),
        schema=require_environment_variable(
            "SNOWFLAKE_SCHEMA"
        ),
        role=require_environment_variable(
            "SNOWFLAKE_ROLE"
        ),
    )


def export_table(
    connection,
    database: str,
    schema: str,
    table_name: str,
) -> list[dict[str, Any]]:
    """Export one Snowflake table into RAG documents."""

    qualified_table = (
        f'"{database}"."{schema}"."{table_name}"'
    )

    query = f"SELECT * FROM {qualified_table}"

    cursor = connection.cursor()

    try:
        cursor.execute(query)

        columns = [
            description[0]
            for description in cursor.description
        ]

        rows = cursor.fetchall()

        documents = [
            create_document(
                table_name=table_name,
                row_number=row_number,
                columns=columns,
                row=row,
            )
            for row_number, row in enumerate(
                rows,
                start=1,
            )
        ]

        print(
            f"Exported {len(documents):>4} rows "
            f"from {table_name}"
        )

        return documents

    finally:
        cursor.close()


def main() -> None:
    """Build the complete local knowledge base."""

    load_dotenv(ENV_FILE)

    database = require_environment_variable(
        "SNOWFLAKE_DATABASE"
    ).upper()

    schema = require_environment_variable(
        "SNOWFLAKE_SCHEMA"
    ).upper()

    DATA_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    print("=" * 70)
    print("BUILDING BENGALURU MOBILITY KNOWLEDGE BASE")
    print("=" * 70)

    connection = None
    all_documents: list[dict[str, Any]] = []

    try:
        connection = connect_to_snowflake()

        print("\nSnowflake connection successful.\n")

        for table_name in KNOWLEDGE_TABLES:
            try:
                documents = export_table(
                    connection=connection,
                    database=database,
                    schema=schema,
                    table_name=table_name,
                )

                all_documents.extend(documents)

            except Exception as table_error:
                print(
                    f"Skipped {table_name}: "
                    f"{table_error}"
                )

        if not all_documents:
            raise RuntimeError(
                "No documents were exported from Snowflake."
            )

        knowledge_base = {
            "project": (
                "Bengaluru Urban Mobility Intelligence"
            ),
            "database": database,
            "schema": schema,
            "document_count": len(all_documents),
            "source_models": KNOWLEDGE_TABLES,
            "documents": all_documents,
        }

        with OUTPUT_FILE.open(
            "w",
            encoding="utf-8",
        ) as output_file:
            json.dump(
                knowledge_base,
                output_file,
                indent=2,
                ensure_ascii=False,
            )

        print("\n" + "=" * 70)
        print(
            f"Knowledge base created with "
            f"{len(all_documents)} documents."
        )
        print(f"Saved to: {OUTPUT_FILE}")
        print("=" * 70)

    except Exception as exc:
        print("\nKnowledge-base export failed.")
        print(f"Error type: {type(exc).__name__}")
        print(f"Error details: {exc}")
        sys.exit(1)

    finally:
        if connection is not None:
            connection.close()


if __name__ == "__main__":
    main()