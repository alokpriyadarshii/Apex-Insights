# Performance Optimization Notes

Apex Insights writes curated datasets as partitioned Parquet so downstream analytics can scan less data and reuse stable, denormalized gold tables.

## Partitioning

- Bronze and silver transactions are partitioned by `event_date`.
- Gold summaries are partitioned by `month`.
- High-cardinality fields such as `transaction_id` stay out of partition paths to avoid tiny files.

## Spark Execution Choices

- Small customer dimension data is broadcast into transaction transforms.
- Reused DataFrames are cached inside the pipeline before multiple write, quality, and reconciliation actions consume them.
- The local development profile keeps shuffle partitions low so the sample pipeline runs quickly.

## Production Scaling Notes

- Compact small files after incremental writes.
- Select only required report columns.
- Keep denormalized gold tables for repeated dashboard queries.
- Add cluster-level monitoring for long-running stages, skew, and failed tasks.
