from __future__ import annotations

from pyspark.sql import DataFrame, Window
from pyspark.sql import functions as F

VALID_CURRENCIES = ["USD", "INR", "EUR", "GBP"]


def bronze_transactions(raw_transactions: DataFrame) -> DataFrame:
    return (
        raw_transactions.select(
            F.trim("transaction_id").alias("transaction_id"),
            F.trim("customer_id").alias("customer_id"),
            F.trim("account_id").alias("account_id"),
            F.trim("merchant_category").alias("merchant_category"),
            F.to_timestamp("transaction_ts").alias("transaction_ts"),
            F.to_date(F.to_timestamp("transaction_ts")).alias("event_date"),
            F.col("amount").cast("double").alias("amount"),
            F.upper(F.trim("currency")).alias("currency"),
            F.lower(F.trim("channel")).alias("channel"),
            F.lower(F.trim("status")).alias("status"),
        )
        .withColumn("ingested_at", F.current_timestamp())
        .withColumn("source_system", F.lit("sample_core_banking"))
    )


def silver_transactions(bronze_df: DataFrame, customers_df: DataFrame) -> DataFrame:
    valid_transactions = bronze_df.where(
        F.col("transaction_id").isNotNull()
        & F.col("customer_id").isNotNull()
        & F.col("amount").isNotNull()
        & (F.col("amount") >= 0)
        & F.col("currency").isin(VALID_CURRENCIES)
        & F.col("transaction_ts").isNotNull()
    )

    active_customers = customers_df.select("customer_id").distinct()

    return (
        valid_transactions.join(F.broadcast(active_customers), "customer_id", "inner")
        .withColumn(
            "amount_band",
            F.when(F.col("amount") >= 1000, F.lit("high"))
            .when(F.col("amount") >= 250, F.lit("medium"))
            .otherwise(F.lit("low")),
        )
        .withColumn("is_high_value", F.col("amount") >= 1000)
    )


def rejected_transactions(bronze_df: DataFrame, customers_df: DataFrame) -> DataFrame:
    known_customers = customers_df.select("customer_id").distinct()
    with_customer_flag = bronze_df.join(
        F.broadcast(known_customers.withColumn("known_customer", F.lit(True))),
        "customer_id",
        "left",
    )

    return (
        with_customer_flag.withColumn(
            "reject_reason",
            F.when(F.col("transaction_id").isNull(), F.lit("missing_transaction_id"))
            .when(F.col("customer_id").isNull(), F.lit("missing_customer_id"))
            .when(F.col("amount").isNull(), F.lit("missing_amount"))
            .when(F.col("amount") < 0, F.lit("negative_amount"))
            .when(~F.col("currency").isin(VALID_CURRENCIES), F.lit("invalid_currency"))
            .when(F.col("transaction_ts").isNull(), F.lit("invalid_timestamp"))
            .when(F.col("known_customer").isNull(), F.lit("unknown_customer"))
        )
        .where(F.col("reject_reason").isNotNull())
        .drop("known_customer")
    )


def customer_profile_history(customers_df: DataFrame) -> DataFrame:
    history_window = Window.partitionBy("customer_id").orderBy("profile_updated_at")
    record_hash = F.sha2(
        F.concat_ws(
            "||",
            "customer_name",
            "risk_segment",
            "city",
            F.col("risk_score").cast("string"),
        ),
        256,
    )

    return (
        customers_df.withColumn("customer_sk", F.monotonically_increasing_id() + 1)
        .withColumn("record_hash", record_hash)
        .withColumn("valid_from", F.to_date("profile_updated_at"))
        .withColumn(
            "valid_to",
            F.date_sub(F.to_date(F.lead("profile_updated_at").over(history_window)), 1),
        )
        .withColumn("is_current", F.col("valid_to").isNull())
        .select(
            "customer_sk",
            "customer_id",
            "customer_name",
            "risk_segment",
            "city",
            "risk_score",
            "valid_from",
            "valid_to",
            "is_current",
            "record_hash",
        )
    )


def customer_risk_summary(
    silver_transactions_df: DataFrame, customer_history_df: DataFrame
) -> DataFrame:
    current_customers = customer_history_df.where("is_current").select(
        "customer_id", "risk_segment", "city"
    )

    return (
        silver_transactions_df.join(F.broadcast(current_customers), "customer_id", "left")
        .withColumn("month", F.date_trunc("month", "transaction_ts").cast("date"))
        .groupBy("month", "risk_segment", "city")
        .agg(
            F.countDistinct("customer_id").alias("active_customers"),
            F.count("*").alias("transaction_count"),
            F.round(F.sum("amount"), 2).alias("total_amount"),
            F.round(F.avg("amount"), 2).alias("avg_transaction_amount"),
            F.sum(F.col("is_high_value").cast("int")).alias("high_value_transactions"),
        )
        .orderBy("month", "risk_segment", "city")
    )


def monthly_revenue_summary(silver_transactions_df: DataFrame) -> DataFrame:
    return (
        silver_transactions_df.withColumn(
            "month", F.date_trunc("month", "transaction_ts").cast("date")
        )
        .groupBy("month", "currency", "merchant_category")
        .agg(
            F.count("*").alias("transaction_count"),
            F.round(F.sum("amount"), 2).alias("total_amount"),
            F.round(F.avg("amount"), 2).alias("avg_amount"),
        )
        .orderBy("month", "currency", "merchant_category")
    )
