-- Raw to bronze record count reconciliation.
SELECT
    'raw_to_bronze_transaction_count' AS check_name,
    (SELECT COUNT(*) FROM raw.transactions) AS left_value,
    (SELECT COUNT(*) FROM bronze.transactions) AS right_value;

-- Bronze valid plus rejected records equals all bronze records.
SELECT
    'bronze_valid_plus_rejected_records' AS check_name,
    (SELECT COUNT(*) FROM bronze.transactions) AS left_value,
    (SELECT COUNT(*) FROM silver.clean_transactions)
        + (SELECT COUNT(*) FROM bronze.rejected_transactions) AS right_value;

-- Silver amount total matches valid bronze amount total.
SELECT
    'silver_amount_matches_bronze_valid_amount' AS check_name,
    (SELECT SUM(amount) FROM bronze.transactions WHERE transaction_id NOT IN (
        SELECT transaction_id FROM bronze.rejected_transactions
    )) AS left_value,
    (SELECT SUM(amount) FROM silver.clean_transactions) AS right_value;

-- Gold monthly aggregate amount reconciles with silver transactions.
SELECT
    'gold_monthly_amount_matches_silver_amount' AS check_name,
    (SELECT SUM(amount) FROM silver.clean_transactions) AS left_value,
    (SELECT SUM(total_amount) FROM gold.monthly_revenue_summary) AS right_value;
