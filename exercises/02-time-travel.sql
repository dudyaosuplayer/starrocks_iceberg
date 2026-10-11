-- Lab 02: Snapshots and time travel (needs ETL: day1 then day2).
-- VERSION AS OF does not accept a subquery; a user variable or literal snapshot_id works.
-- TIMESTAMP AS OF rejects fractional seconds (copy committed_at without .fraction, or use now()).

SELECT
    committed_at,
    snapshot_id,
    parent_id,
    operation
FROM demo.sales.sales$snapshots
ORDER BY committed_at;

SELECT COUNT(*) AS current_cnt FROM demo.sales.sales;
SELECT * FROM demo.sales.sales ORDER BY sale_id;

SET @first_snapshot = (
    SELECT snapshot_id
    FROM demo.sales.sales$snapshots
    ORDER BY committed_at
    LIMIT 1
);

SELECT @first_snapshot AS first_snapshot_id;

SELECT COUNT(*) AS rows_at_first_snapshot
FROM demo.sales.sales VERSION AS OF @first_snapshot;

SELECT *
FROM demo.sales.sales VERSION AS OF @first_snapshot
ORDER BY sale_id;

SELECT COUNT(*) AS rows_now FROM demo.sales.sales;

-- Current snapshot via clock. For a historical clock time, use a literal
-- 'YYYY-MM-DD HH:MM:SS' *after* the first committed_at (no microseconds).
SELECT COUNT(*) AS rows_now_ts
FROM demo.sales.sales TIMESTAMP AS OF now();
