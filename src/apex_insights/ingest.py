from __future__ import annotations

from pathlib import Path

from pyspark.sql import DataFrame, SparkSession
from pyspark.sql.types import (
    DoubleType,
    StringType,
    StructField,
    StructType,
    TimestampType,
)

TRANSACTION_SCHEMA = StructType(
    [
        StructField("transaction_id", StringType(), False),
        StructField("customer_id", StringType(), False),
        StructField("account_id", StringType(), False),
        StructField("merchant_category", StringType(), True),
        StructField("transaction_ts", StringType(), True),
        StructField("amount", DoubleType(), True),
        StructField("currency", StringType(), True),
        StructField("channel", StringType(), True),
        StructField("status", StringType(), True),
    ]
)

CUSTOMER_SCHEMA = StructType(
    [
        StructField("customer_id", StringType(), False),
        StructField("customer_name", StringType(), True),
        StructField("city", StringType(), True),
        StructField("risk_segment", StringType(), True),
        StructField("risk_score", DoubleType(), True),
        StructField("profile_updated_at", TimestampType(), True),
    ]
)


def read_transactions(spark: SparkSession, raw_dir: Path) -> DataFrame:
    return (
        spark.read.option("header", True)
        .schema(TRANSACTION_SCHEMA)
        .csv(str(raw_dir / "transactions.csv"))
    )


def read_customers(spark: SparkSession, raw_dir: Path) -> DataFrame:
    return spark.read.schema(CUSTOMER_SCHEMA).json(str(raw_dir / "customers.json"))
