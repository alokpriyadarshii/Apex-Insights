from __future__ import annotations

from pathlib import Path

from pyspark.sql import DataFrame


def overwrite_parquet(df: DataFrame, output_path: Path, *partition_cols: str) -> None:
    writer = df.write.mode("overwrite")
    if partition_cols:
        writer = writer.partitionBy(*partition_cols)
    writer.parquet(str(output_path))


def overwrite_csv(df: DataFrame, output_path: Path) -> None:
    df.coalesce(1).write.mode("overwrite").option("header", True).csv(str(output_path))
