SELECT
    customer_id,
    DATE_TRUNC('month', transaction_ts) AS month,
    COUNT(*) AS transaction_count,
    SUM(amount) AS monthly_spend,
    AVG(amount) AS avg_transaction_amount,
    SUM(CASE WHEN is_high_value THEN 1 ELSE 0 END) AS high_value_transactions
FROM silver.clean_transactions
GROUP BY
    customer_id,
    DATE_TRUNC('month', transaction_ts)
ORDER BY
    month,
    customer_id;
