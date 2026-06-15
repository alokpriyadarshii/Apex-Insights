.PHONY: install test lint pipeline validate-parquet clean

install:
	python -m pip install -r requirements.txt

test:
	python -m pytest

lint:
	python -m ruff check src tests/python

pipeline:
	python -m apex_insights.pipeline

validate-parquet:
	test -d artifacts/lakehouse/bronze/transactions_parquet
	test -d artifacts/lakehouse/silver/clean_transactions_parquet
	test -d artifacts/lakehouse/gold/customer_risk_summary_parquet
	test -f artifacts/reports/data_quality_report.json
	test -f artifacts/reports/data_quality_report.md
	test -f artifacts/reconciliation/reconciliation_report.csv

clean:
	rm -rf artifacts/lakehouse artifacts/reports artifacts/reconciliation .pytest_cache
