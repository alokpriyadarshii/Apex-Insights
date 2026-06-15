CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

CREATE TABLE IF NOT EXISTS bronze.transactions (
    transaction_id VARCHAR(64) NOT NULL,
    customer_id VARCHAR(64) NOT NULL,
    account_id VARCHAR(64) NOT NULL,
    merchant_category VARCHAR(128),
    transaction_ts TIMESTAMP,
    event_date DATE,
    amount DECIMAL(18, 2),
    currency CHAR(3),
    channel VARCHAR(32),
    status VARCHAR(32),
    ingested_at TIMESTAMP,
    source_system VARCHAR(128)
);

CREATE TABLE IF NOT EXISTS silver.clean_transactions (
    customer_id VARCHAR(64) NOT NULL,
    transaction_id VARCHAR(64) NOT NULL,
    account_id VARCHAR(64) NOT NULL,
    merchant_category VARCHAR(128),
    transaction_ts TIMESTAMP NOT NULL,
    event_date DATE NOT NULL,
    amount DECIMAL(18, 2) NOT NULL,
    currency CHAR(3) NOT NULL,
    channel VARCHAR(32),
    status VARCHAR(32),
    amount_band VARCHAR(16),
    is_high_value BOOLEAN
);

CREATE TABLE IF NOT EXISTS silver.customer_profile_history (
    customer_sk BIGINT NOT NULL,
    customer_id VARCHAR(64) NOT NULL,
    customer_name VARCHAR(256),
    risk_segment VARCHAR(32),
    city VARCHAR(128),
    risk_score DECIMAL(8, 2),
    valid_from DATE NOT NULL,
    valid_to DATE,
    is_current BOOLEAN NOT NULL,
    record_hash VARCHAR(256)
);

CREATE TABLE IF NOT EXISTS gold.customer_risk_summary (
    month DATE NOT NULL,
    risk_segment VARCHAR(32),
    city VARCHAR(128),
    active_customers BIGINT,
    transaction_count BIGINT,
    total_amount DECIMAL(18, 2),
    avg_transaction_amount DECIMAL(18, 2),
    high_value_transactions BIGINT
);
