-- Monthly customer spend using window functions.
WITH monthly_customer_spend AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', transaction_ts) AS month,
        SUM(amount) AS monthly_spend
    FROM silver.clean_transactions
    GROUP BY
        customer_id,
        DATE_TRUNC('month', transaction_ts)
)
SELECT
    customer_id,
    month,
    monthly_spend,
    AVG(monthly_spend) OVER (
        PARTITION BY customer_id
        ORDER BY month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS rolling_3_month_avg,
    monthly_spend - LAG(monthly_spend) OVER (
        PARTITION BY customer_id
        ORDER BY month
    ) AS month_over_month_change
FROM monthly_customer_spend
ORDER BY customer_id, month;

-- Current customer profile from an SCD Type 2 history table.
SELECT
    customer_sk,
    customer_id,
    customer_name,
    risk_segment,
    city,
    valid_from
FROM silver.customer_profile_history
WHERE is_current = TRUE;
