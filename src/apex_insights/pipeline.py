from __future__ import annotations

from apex_insights.config import PipelinePaths, build_spark
from apex_insights.ingest import read_customers, read_transactions
from apex_insights.model import transaction_monitoring_features
from apex_insights.quality import evaluate_quality, write_quality_reports
from apex_insights.reconcile import reconcile_layers, write_reconciliation_report
from apex_insights.transform import (
    bronze_transactions,
    customer_profile_history,
    customer_risk_summary,
    monthly_revenue_summary,
    rejected_transactions,
    silver_transactions,
)
from apex_insights.write import overwrite_parquet


def run_pipeline() -> None:
    paths = PipelinePaths()
    spark = build_spark()
    try:
        raw_transactions_df = read_transactions(spark, paths.raw_dir).cache()
        customers_df = read_customers(spark, paths.raw_dir).cache()

        bronze_df = bronze_transactions(raw_transactions_df).cache()
        rejected_df = rejected_transactions(bronze_df, customers_df).cache()
        silver_df = silver_transactions(bronze_df, customers_df).cache()
        customer_history_df = customer_profile_history(customers_df).cache()
        risk_summary_df = customer_risk_summary(silver_df, customer_history_df).cache()
        monthly_summary_df = monthly_revenue_summary(silver_df).cache()
        monitoring_features_df = transaction_monitoring_features(silver_df).cache()

        overwrite_parquet(
            bronze_df,
            paths.bronze_dir / "transactions_parquet",
            "event_date",
        )
        overwrite_parquet(
            rejected_df,
            paths.bronze_dir / "rejected_transactions_parquet",
            "event_date",
        )
        overwrite_parquet(
            silver_df,
            paths.silver_dir / "clean_transactions_parquet",
            "event_date",
        )
        overwrite_parquet(
            customer_history_df,
            paths.silver_dir / "customer_profile_history_parquet",
        )
        overwrite_parquet(
            monitoring_features_df,
            paths.silver_dir / "transaction_monitoring_features_parquet",
            "event_date",
        )
        overwrite_parquet(
            risk_summary_df,
            paths.gold_dir / "customer_risk_summary_parquet",
            "month",
        )
        overwrite_parquet(
            monthly_summary_df,
            paths.gold_dir / "monthly_revenue_summary_parquet",
            "month",
        )

        quality_checks = evaluate_quality(bronze_df, customers_df, silver_df)
        write_quality_reports(quality_checks, paths.report_dir)

        reconciliation_checks = reconcile_layers(
            raw_transactions_df,
            bronze_df,
            rejected_df,
            silver_df,
            monthly_summary_df,
        )
        write_reconciliation_report(reconciliation_checks, paths.reconciliation_dir)
    finally:
        spark.stop()


def main() -> None:
    run_pipeline()


if __name__ == "__main__":
    main()
