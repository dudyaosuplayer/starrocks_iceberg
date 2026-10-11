-- Lab 07: Small files + compaction via rewrite_data_files (StarRocks 4.0+, no Spark).

SET CATALOG demo;
CREATE DATABASE IF NOT EXISTS sales;

DROP TABLE IF EXISTS demo.sales.sales_small_files;
CREATE TABLE demo.sales.sales_small_files (
    sale_id BIGINT,
    customer_id BIGINT,
    amount DOUBLE,
    sale_date DATE
)
PARTITION BY (day(sale_date));

-- Many commits => many tiny Parquet files.
INSERT INTO demo.sales.sales_small_files VALUES (1, 101, 10, DATE '2025-01-01');
INSERT INTO demo.sales.sales_small_files VALUES (2, 102, 20, DATE '2025-01-01');
INSERT INTO demo.sales.sales_small_files VALUES (3, 103, 30, DATE '2025-01-01');
INSERT INTO demo.sales.sales_small_files VALUES (4, 104, 40, DATE '2025-01-01');
INSERT INTO demo.sales.sales_small_files VALUES (5, 105, 50, DATE '2025-01-01');
INSERT INTO demo.sales.sales_small_files VALUES (6, 106, 60, DATE '2025-01-01');

SELECT 'before compact' AS stage, COUNT(*) AS file_cnt
FROM demo.sales.sales_small_files$files;

SELECT file_path, record_count, file_size_in_bytes
FROM demo.sales.sales_small_files$files;

SELECT COUNT(*) AS row_cnt FROM demo.sales.sales_small_files;

-- Merge files smaller than 128 MiB (all of ours). rewrite_all forces a rewrite.
ALTER TABLE demo.sales.sales_small_files
EXECUTE rewrite_data_files("min_file_size_bytes"=134217728, "rewrite_all"=true);

SELECT 'after compact' AS stage, COUNT(*) AS file_cnt
FROM demo.sales.sales_small_files$files;

SELECT file_path, record_count, file_size_in_bytes
FROM demo.sales.sales_small_files$files;

SELECT COUNT(*) AS row_cnt FROM demo.sales.sales_small_files;
SELECT * FROM demo.sales.sales_small_files ORDER BY sale_id;

SELECT committed_at, snapshot_id, operation
FROM demo.sales.sales_small_files$snapshots
ORDER BY committed_at;
