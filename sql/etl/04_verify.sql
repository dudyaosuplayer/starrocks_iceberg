-- Post-ETL checks: rows, snapshots, files, partitions.

SELECT * FROM demo.sales.sales ORDER BY sale_id;

SELECT
    committed_at,
    snapshot_id,
    parent_id,
    operation
FROM demo.sales.sales$snapshots
ORDER BY committed_at;

SELECT
    content,
    file_path,
    file_format,
    record_count,
    file_size_in_bytes
FROM demo.sales.sales$files;

SELECT * FROM demo.sales.sales$partitions;

SELECT * FROM demo.sales.sales$history;
