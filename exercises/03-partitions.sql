-- Lab 03: Hidden partitioning + partition prune.

SELECT * FROM demo.sales.sales$partitions;

SELECT
    file_path,
    record_count,
    lower_bounds,
    upper_bounds
FROM demo.sales.sales$files;

-- Filter on the source column, not on a Hive-style partition column name.
SELECT * FROM demo.sales.sales WHERE sale_date = '2025-01-01' ORDER BY sale_id;
SELECT * FROM demo.sales.sales WHERE sale_date >= '2025-01-02' ORDER BY sale_id;

-- Look for IcebergScanNode / partition predicates / selected files in the plan.
EXPLAIN SELECT * FROM demo.sales.sales WHERE sale_date = '2025-01-01';
EXPLAIN SELECT * FROM demo.sales.sales WHERE sale_date >= '2025-01-02';

-- Contrast: unfiltered scan.
EXPLAIN SELECT * FROM demo.sales.sales;
