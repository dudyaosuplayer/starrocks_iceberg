-- Lab 08: Iceberg vs native DUPLICATE KEY (same sales rows).

-- --- Iceberg (lakehouse) ---
SET CATALOG demo;
CREATE DATABASE IF NOT EXISTS sales;

DROP TABLE IF EXISTS demo.sales.sales_cmp;
CREATE TABLE demo.sales.sales_cmp (
    sale_id BIGINT,
    customer_id BIGINT,
    amount DOUBLE,
    sale_date DATE
)
PARTITION BY (day(sale_date));

INSERT INTO demo.sales.sales_cmp VALUES
    (1, 101, 100, DATE '2025-01-01'),
    (2, 102, 200, DATE '2025-01-01'),
    (3, 103, 300, DATE '2025-01-01');

INSERT INTO demo.sales.sales_cmp VALUES
    (4, 101, 400, DATE '2025-01-02'),
    (5, 104, 500, DATE '2025-01-02'),
    (6, 105, 600, DATE '2025-01-02');

SELECT 'iceberg' AS engine, COUNT(*) AS n FROM demo.sales.sales_cmp;
SELECT committed_at, snapshot_id, operation
FROM demo.sales.sales_cmp$snapshots
ORDER BY committed_at;

SET @iceberg_first = (
    SELECT snapshot_id FROM demo.sales.sales_cmp$snapshots ORDER BY committed_at LIMIT 1
);
SELECT COUNT(*) AS iceberg_day1
FROM demo.sales.sales_cmp VERSION AS OF @iceberg_first;

-- --- Native StarRocks OLAP ---
SET CATALOG default_catalog;
CREATE DATABASE IF NOT EXISTS sales_native;
USE sales_native;

DROP TABLE IF EXISTS sales_native.sales_dup;
CREATE TABLE sales_native.sales_dup (
    sale_id BIGINT NOT NULL,
    customer_id BIGINT,
    amount DOUBLE,
    sale_date DATE
)
DUPLICATE KEY(sale_id)
DISTRIBUTED BY HASH(sale_id) BUCKETS 1
PROPERTIES ("replication_num" = "1");

INSERT INTO sales_native.sales_dup VALUES
    (1, 101, 100, DATE '2025-01-01'),
    (2, 102, 200, DATE '2025-01-01'),
    (3, 103, 300, DATE '2025-01-01');

INSERT INTO sales_native.sales_dup VALUES
    (4, 101, 400, DATE '2025-01-02'),
    (5, 104, 500, DATE '2025-01-02'),
    (6, 105, 600, DATE '2025-01-02');

SELECT 'native' AS engine, COUNT(*) AS n FROM sales_native.sales_dup;
SELECT * FROM sales_native.sales_dup ORDER BY sale_id;

-- Native table has no Iceberg metadata tables / VERSION AS OF.
-- The next statement is expected to FAIL — that is the point of the lab.
-- SELECT * FROM sales_native.sales_dup$snapshots;
-- SELECT * FROM sales_native.sales_dup VERSION AS OF 1;

SHOW CREATE TABLE demo.sales.sales_cmp;
SHOW CREATE TABLE sales_native.sales_dup;
