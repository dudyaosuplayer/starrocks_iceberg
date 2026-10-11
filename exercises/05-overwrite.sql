-- Lab 05: Append vs overwrite.
-- Recreate a clean two-day table first (this lab is self-contained).

SET CATALOG demo;
CREATE DATABASE IF NOT EXISTS sales;

DROP TABLE IF EXISTS demo.sales.sales;
CREATE TABLE demo.sales.sales (
    sale_id BIGINT,
    customer_id BIGINT,
    amount DOUBLE,
    sale_date DATE
)
PARTITION BY (day(sale_date));

INSERT INTO demo.sales.sales VALUES
    (1, 101, 100, DATE '2025-01-01'),
    (2, 102, 200, DATE '2025-01-01'),
    (3, 103, 300, DATE '2025-01-01');

INSERT INTO demo.sales.sales VALUES
    (4, 101, 400, DATE '2025-01-02'),
    (5, 104, 500, DATE '2025-01-02'),
    (6, 105, 600, DATE '2025-01-02');

SELECT 'before overwrite' AS stage, COUNT(*) AS n FROM demo.sales.sales;
SELECT * FROM demo.sales.sales ORDER BY sale_id;

SELECT committed_at, snapshot_id, parent_id, operation
FROM demo.sales.sales$snapshots
ORDER BY committed_at;

-- Dynamic overwrite (v3.4+): only partitions present in the INSERT are replaced.
-- Day2 must stay. Corrected day1 amounts: 111/222/333.
SET dynamic_overwrite = true;

INSERT OVERWRITE demo.sales.sales
VALUES
    (1, 101, 111, DATE '2025-01-01'),
    (2, 102, 222, DATE '2025-01-01'),
    (3, 103, 333, DATE '2025-01-01');

SELECT 'after overwrite' AS stage, COUNT(*) AS n FROM demo.sales.sales;
SELECT * FROM demo.sales.sales ORDER BY sale_id;

SELECT committed_at, snapshot_id, parent_id, operation
FROM demo.sales.sales$snapshots
ORDER BY committed_at;

-- Time travel: first snapshot still has original amounts 100/200/300.
SET @first_snapshot = (
    SELECT snapshot_id FROM demo.sales.sales$snapshots ORDER BY committed_at LIMIT 1
);
SELECT *
FROM demo.sales.sales VERSION AS OF @first_snapshot
ORDER BY sale_id;
