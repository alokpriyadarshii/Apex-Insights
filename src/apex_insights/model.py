from __future__ import annotations

from pyspark.sql import DataFrame
from pyspark.sql import functions as F


def transaction_monitoring_features(silver_transactions_df: DataFrame) -> DataFrame:
    return silver_transactions_df.select(
        "transaction_id",
        "customer_id",
        "event_date",
        "merchant_category",
        "amount",
        "currency",
        "channel",
        F.when(F.col("amount") >= 1000, F.lit(1)).otherwise(F.lit(0)).alias(
            "high_value_flag"
        ),
        F.when(F.col("channel") == "card", F.lit(1)).otherwise(F.lit(0)).alias(
            "card_channel_flag"
        ),
    )
