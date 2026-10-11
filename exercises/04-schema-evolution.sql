-- Lab 04: Schema evolution. Old Parquet files stay readable.

DESC demo.sales.sales;

ALTER TABLE demo.sales.sales ADD COLUMN region STRING;

DESC demo.sales.sales;

-- Existing rows: new column is NULL (old parquet has no region).
SELECT sale_id, amount, sale_date, region
FROM demo.sales.sales
ORDER BY sale_id;

INSERT INTO demo.sales.sales (sale_id, customer_id, amount, sale_date, region)
VALUES
    (7, 106, 700, DATE '2025-01-03', 'eu');

SELECT sale_id, amount, sale_date, region
FROM demo.sales.sales
ORDER BY sale_id;

-- Time travel to the first snapshot: region column may be missing or NULL
-- depending on how StarRocks projects evolved schema onto old snapshots.
SELECT
    committed_at,
    snapshot_id
FROM demo.sales.sales$snapshots
ORDER BY committed_at;

-- After ADD COLUMN + INSERT there are extra snapshots.
SET @first_snapshot = (
    SELECT snapshot_id FROM demo.sales.sales$snapshots ORDER BY committed_at LIMIT 1
);
SELECT @first_snapshot AS first_snapshot_id;
SELECT COUNT(*) AS rows_at_first
FROM demo.sales.sales VERSION AS OF @first_snapshot;
