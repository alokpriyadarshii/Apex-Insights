from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path

from pyspark.sql import DataFrame
from pyspark.sql import functions as F


@dataclass(frozen=True)
class ReconciliationCheck:
    check_name: str
    left_value: float
    right_value: float
    status: str
    details: str


def _amount(df: DataFrame, column: str = "amount") -> float:
    value = df.select(F.round(F.sum(column), 2).alias("total")).first()["total"]
    return float(value or 0)


def _status(left_value: float, right_value: float) -> str:
    return "PASS" if round(left_value, 2) == round(right_value, 2) else "FAIL"


def reconcile_layers(
    raw_transactions_df: DataFrame,
    bronze_transactions_df: DataFrame,
    rejected_transactions_df: DataFrame,
    silver_transactions_df: DataFrame,
    monthly_revenue_summary_df: DataFrame,
) -> list[ReconciliationCheck]:
    raw_count = raw_transactions_df.count()
    bronze_count = bronze_transactions_df.count()
    rejected_count = rejected_transactions_df.count()
    bronze_valid_count = bronze_count - rejected_count
    bronze_valid_df = bronze_transactions_df.join(
        rejected_transactions_df.select("transaction_id"),
        "transaction_id",
        "left_anti",
    )
    bronze_valid_amount = _amount(bronze_valid_df)
    silver_amount = _amount(silver_transactions_df)
    gold_amount = _amount(monthly_revenue_summary_df, "total_amount")

    return [
        ReconciliationCheck(
            "raw_to_bronze_transaction_count",
            raw_count,
            bronze_count,
            _status(raw_count, bronze_count),
            "Raw transaction count should equal bronze transaction count.",
        ),
        ReconciliationCheck(
            "bronze_valid_plus_rejected_records",
            bronze_count,
            bronze_valid_count + rejected_count,
            _status(bronze_count, bronze_valid_count + rejected_count),
            "Bronze valid records plus rejected records should equal all bronze records.",
        ),
        ReconciliationCheck(
            "silver_amount_matches_bronze_valid_amount",
            bronze_valid_amount,
            silver_amount,
            _status(bronze_valid_amount, silver_amount),
            "Silver transaction totals should match bronze valid transaction totals.",
        ),
        ReconciliationCheck(
            "gold_monthly_amount_matches_silver_amount",
            silver_amount,
            gold_amount,
            _status(silver_amount, gold_amount),
            "Gold monthly aggregates should reconcile with silver transaction totals.",
        ),
    ]


def write_reconciliation_report(
    checks: list[ReconciliationCheck], reconciliation_dir: Path
) -> None:
    reconciliation_dir.mkdir(parents=True, exist_ok=True)
    output_path = reconciliation_dir / "reconciliation_report.csv"
    with output_path.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.DictWriter(
            csv_file,
            fieldnames=["check_name", "left_value", "right_value", "status", "details"],
        )
        writer.writeheader()
        for check in checks:
            writer.writerow(
                {
                    "check_name": check.check_name,
                    "left_value": check.left_value,
                    "right_value": check.right_value,
                    "status": check.status,
                    "details": check.details,
                }
            )
