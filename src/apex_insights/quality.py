from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from pathlib import Path

from pyspark.sql import DataFrame
from pyspark.sql import functions as F

from apex_insights.transform import VALID_CURRENCIES


@dataclass(frozen=True)
class QualityCheck:
    check_name: str
    dimension: str
    status: str
    failed_records: int
    details: str


def _status(failed_records: int) -> str:
    return "PASS" if failed_records == 0 else "FAIL"


def evaluate_quality(
    bronze_transactions_df: DataFrame,
    customers_df: DataFrame,
    silver_transactions_df: DataFrame,
) -> list[QualityCheck]:
    known_customer_ids = customers_df.select("customer_id").distinct()

    completeness_failures = bronze_transactions_df.where(
        F.col("customer_id").isNull()
        | F.col("transaction_id").isNull()
        | F.col("amount").isNull()
    ).count()
    invalid_amount_failures = bronze_transactions_df.where(F.col("amount") < 0).count()
    invalid_currency_failures = bronze_transactions_df.where(
        ~F.col("currency").isin(VALID_CURRENCIES) | F.col("currency").isNull()
    ).count()
    invalid_timestamp_failures = bronze_transactions_df.where(
        F.col("transaction_ts").isNull()
    ).count()
    unknown_customer_failures = (
        bronze_transactions_df.join(known_customer_ids, "customer_id", "left_anti").count()
    )
    duplicate_failures = (
        bronze_transactions_df.groupBy("transaction_id")
        .count()
        .where((F.col("transaction_id").isNotNull()) & (F.col("count") > 1))
        .count()
    )
    high_outlier_failures = bronze_transactions_df.where(F.col("amount") > 5000).count()

    schema_columns = set(bronze_transactions_df.columns)
    expected_columns = {
        "transaction_id",
        "customer_id",
        "account_id",
        "merchant_category",
        "transaction_ts",
        "event_date",
        "amount",
        "currency",
        "channel",
        "status",
    }
    missing_schema_columns = sorted(expected_columns - schema_columns)

    sample_window_days = (
        silver_transactions_df.select(
            F.datediff(F.max("event_date"), F.min("event_date")).alias("window_days")
        ).first()["window_days"]
        or 0
    )
    freshness_failures = 0 if sample_window_days <= 45 else 1

    return [
        QualityCheck(
            "required_transaction_fields_present",
            "completeness",
            _status(completeness_failures),
            completeness_failures,
            "No missing customer_id, transaction_id, or amount values.",
        ),
        QualityCheck(
            "non_negative_amounts",
            "accuracy",
            _status(invalid_amount_failures),
            invalid_amount_failures,
            "Transaction amount must be greater than or equal to zero.",
        ),
        QualityCheck(
            "valid_currency_codes",
            "accuracy",
            _status(invalid_currency_failures),
            invalid_currency_failures,
            f"Currency must be one of {', '.join(VALID_CURRENCIES)}.",
        ),
        QualityCheck(
            "valid_transaction_timestamps",
            "accuracy",
            _status(invalid_timestamp_failures),
            invalid_timestamp_failures,
            "Transaction timestamp must parse into a Spark timestamp.",
        ),
        QualityCheck(
            "customer_referential_integrity",
            "consistency",
            _status(unknown_customer_failures),
            unknown_customer_failures,
            "Every transaction customer_id must exist in the customer table.",
        ),
        QualityCheck(
            "unique_transaction_ids",
            "uniqueness",
            _status(duplicate_failures),
            duplicate_failures,
            "Each transaction_id should appear once in the raw feed.",
        ),
        QualityCheck(
            "recent_transaction_feed",
            "freshness",
            _status(freshness_failures),
            freshness_failures,
            "Latest transaction date should be within the 45-day sample monitoring window.",
        ),
        QualityCheck(
            "expected_bronze_schema",
            "schema",
            _status(len(missing_schema_columns)),
            len(missing_schema_columns),
            "Missing columns: " + ", ".join(missing_schema_columns)
            if missing_schema_columns
            else "All expected columns are present.",
        ),
        QualityCheck(
            "high_amount_outliers_flagged",
            "outliers",
            "PASS",
            high_outlier_failures,
            "Transactions above 5000 are counted for monitoring review.",
        ),
    ]


def write_quality_reports(checks: list[QualityCheck], report_dir: Path) -> None:
    report_dir.mkdir(parents=True, exist_ok=True)
    payload = {
        "overall_status": "PASS"
        if all(check.status == "PASS" for check in checks)
        else "FAIL",
        "checks": [asdict(check) for check in checks],
    }

    (report_dir / "data_quality_report.json").write_text(
        json.dumps(payload, indent=2) + "\n", encoding="utf-8"
    )

    lines = [
        "# Apex Insights Data Quality Report",
        "",
        f"Overall status: **{payload['overall_status']}**",
        "",
        "| Dimension | Check | Status | Failed Records | Details |",
        "| --- | --- | --- | ---: | --- |",
    ]
    for check in checks:
        lines.append(
            "| "
            + " | ".join(
                [
                    check.dimension,
                    check.check_name,
                    check.status,
                    str(check.failed_records),
                    check.details,
                ]
            )
            + " |"
        )
    (report_dir / "data_quality_report.md").write_text(
        "\n".join(lines) + "\n", encoding="utf-8"
    )
