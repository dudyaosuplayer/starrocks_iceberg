-- Lab 06: DELETE (Merge-on-Read).
-- StarRocks 4.0: Iceberg DELETE is not supported
--   ERROR: Table of iceberg catalog doesn't support [DELETE].
-- Official DML documents DELETE FROM Iceberg from v4.1.
-- Closest 4.0 equivalent: copy-on-write overwrite of remaining rows (no delete files).

SET CATALOG demo;

SELECT 'before delete' AS stage, COUNT(*) AS n FROM demo.sales.sales;
SELECT * FROM demo.sales.sales ORDER BY sale_id;

SELECT content, file_path, file_format, record_count
FROM demo.sales.sales$files;

-- Uncomment on StarRocks 4.1+ to write Iceberg position/equality deletes:
-- DELETE FROM demo.sales.sales WHERE sale_id = 1;

SET dynamic_overwrite = true;
INSERT OVERWRITE demo.sales.sales
SELECT sale_id, customer_id, amount, sale_date
FROM demo.sales.sales
WHERE sale_id <> 1;

SELECT 'after delete-equiv' AS stage, COUNT(*) AS n FROM demo.sales.sales;
SELECT * FROM demo.sales.sales ORDER BY sale_id;

-- On 4.0 this stays DATA(0) only — overwrite replaced files, no POSITION_DELETES(1).
SELECT content, file_path, file_format, record_count, file_size_in_bytes
FROM demo.sales.sales$files
ORDER BY content, file_path;

SELECT partition_value, record_count, file_count,
       position_delete_file_count, position_delete_record_count,
       equality_delete_file_count, equality_delete_record_count
FROM demo.sales.sales$partitions;

-- History still has the row in the previous snapshot.
SET @prev = (
    SELECT snapshot_id FROM demo.sales.sales$snapshots ORDER BY committed_at DESC LIMIT 1 OFFSET 1
);
SELECT @prev AS previous_snapshot;
SELECT * FROM demo.sales.sales VERSION AS OF @prev ORDER BY sale_id;
