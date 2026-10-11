-- Recreate demo.sales.sales so ETL is idempotent.
SET CATALOG demo;

CREATE DATABASE IF NOT EXISTS sales;

DROP TABLE IF EXISTS demo.sales.sales;

-- Hidden partition: Iceberg day transform on DATE.
-- StarRocks 4.0: PARTITION BY (day(sale_date)) — days(date) is rejected
-- (__iceberg_transform_days(date) has no matching signature).
CREATE TABLE demo.sales.sales (
    sale_id BIGINT,
    customer_id BIGINT,
    amount DOUBLE,
    sale_date DATE
)
PARTITION BY (day(sale_date));

DESC demo.sales.sales;
SHOW CREATE TABLE demo.sales.sales;
