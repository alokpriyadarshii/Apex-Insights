from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from pyspark.sql import SparkSession


@dataclass(frozen=True)
class PipelinePaths:
    repo_root: Path = Path(__file__).resolve().parents[2]

    @property
    def raw_dir(self) -> Path:
        return self.repo_root / "data" / "raw"

    @property
    def lakehouse_dir(self) -> Path:
        return self.repo_root / "artifacts" / "lakehouse"

    @property
    def report_dir(self) -> Path:
        return self.repo_root / "artifacts" / "reports"

    @property
    def reconciliation_dir(self) -> Path:
        return self.repo_root / "artifacts" / "reconciliation"

    @property
    def bronze_dir(self) -> Path:
        return self.lakehouse_dir / "bronze"

    @property
    def silver_dir(self) -> Path:
        return self.lakehouse_dir / "silver"

    @property
    def gold_dir(self) -> Path:
        return self.lakehouse_dir / "gold"


def build_spark(app_name: str = "apex-insights-lakehouse") -> SparkSession:
    return (
        SparkSession.builder.appName(app_name)
        .master("local[2]")
        .config("spark.sql.shuffle.partitions", "2")
        .config("spark.sql.session.timeZone", "UTC")
        .config("spark.driver.host", "127.0.0.1")
        .config("spark.driver.bindAddress", "127.0.0.1")
        .config("spark.ui.enabled", "false")
        .getOrCreate()
    )
