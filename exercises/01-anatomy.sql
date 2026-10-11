-- Lab 01: Anatomy of an Iceberg table (run after scripts/run_etl.sh)

SHOW CATALOGS;

SET CATALOG demo;
SHOW DATABASES;

DESC demo.sales.sales;
SHOW CREATE TABLE demo.sales.sales;

SELECT * FROM demo.sales.sales ORDER BY sale_id;

-- Metadata tables (StarRocks 3.4.1+): snapshots, files, manifests, history.
SELECT
    committed_at,
    snapshot_id,
    parent_id,
    operation,
    manifest_list
FROM demo.sales.sales$snapshots
ORDER BY committed_at;

SELECT
    content,
    file_path,
    file_format,
    record_count,
    file_size_in_bytes
FROM demo.sales.sales$files;

SELECT path, length, added_snapshot_id, added_data_files_count, added_rows_count
FROM demo.sales.sales$manifests;

SELECT * FROM demo.sales.sales$history;

SELECT * FROM demo.sales.sales$metadata_log_entries;
