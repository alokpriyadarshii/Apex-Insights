-- Optimization notes for analytical lakehouse queries:
-- 1. Partition transaction parquet datasets by event_date for selective date filters.
-- 2. Keep high-cardinality identifiers such as transaction_id out of partition columns.
-- 3. Broadcast small dimensions such as customer profile and merchant category tables.
-- 4. Select only required columns in downstream reports to reduce scan cost.
-- 5. Cache reused Spark DataFrames inside the pipeline when multiple actions consume them.
-- 6. Prefer denormalized gold tables for dashboards and repeated analytics queries.
-- 7. Compact small files after incremental writes in production-scale jobs.

SELECT
    event_date,
    COUNT(*) AS file_pruning_candidate_rows,
    SUM(amount) AS daily_amount
FROM silver.clean_transactions
WHERE event_date BETWEEN DATE '2026-06-01' AND DATE '2026-06-30'
GROUP BY event_date
ORDER BY event_date;
