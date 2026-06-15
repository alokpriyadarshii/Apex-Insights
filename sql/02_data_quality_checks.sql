-- Completeness: no missing required transaction fields.
SELECT
    COUNT(*) AS failed_records
FROM bronze.transactions
WHERE customer_id IS NULL
   OR transaction_id IS NULL
   OR amount IS NULL;

-- Accuracy: amount, currency, and timestamp checks.
SELECT
    COUNT(*) AS failed_records
FROM bronze.transactions
WHERE amount < 0
   OR currency NOT IN ('USD', 'INR', 'EUR', 'GBP')
   OR transaction_ts IS NULL;

-- Consistency: every transaction customer must exist in the customer dimension.
SELECT
    t.customer_id,
    COUNT(*) AS missing_customer_transactions
FROM bronze.transactions AS t
LEFT JOIN silver.customer_profile_history AS c
    ON t.customer_id = c.customer_id
   AND c.is_current = TRUE
WHERE c.customer_id IS NULL
GROUP BY t.customer_id;

-- Uniqueness: duplicate transaction identifier check.
SELECT
    transaction_id,
    COUNT(*) AS cnt
FROM silver.clean_transactions
GROUP BY transaction_id
HAVING COUNT(*) > 1;

-- Outlier monitoring: high amount transactions flagged for review.
SELECT
    transaction_id,
    customer_id,
    amount,
    currency,
    event_date
FROM silver.clean_transactions
WHERE amount > 5000
ORDER BY amount DESC;
