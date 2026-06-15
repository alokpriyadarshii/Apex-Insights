from apex_insights.config import PipelinePaths
from apex_insights.transform import VALID_CURRENCIES


def test_pipeline_paths_use_lakehouse_layers() -> None:
    paths = PipelinePaths()

    assert paths.bronze_dir.name == "bronze"
    assert paths.silver_dir.name == "silver"
    assert paths.gold_dir.name == "gold"


def test_supported_currency_controls_are_explicit() -> None:
    assert {"USD", "INR", "EUR", "GBP"}.issubset(set(VALID_CURRENCIES))
