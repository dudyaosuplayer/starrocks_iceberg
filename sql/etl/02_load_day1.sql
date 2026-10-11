-- Load landing CSV for 2025-01-01 into Iceberg (append snapshot).
-- FILES() reads MinIO with the same path-style credentials as the catalog.

INSERT INTO demo.sales.sales (sale_id, customer_id, amount, sale_date)
SELECT
    CAST($1 AS BIGINT) AS sale_id,
    CAST($2 AS BIGINT) AS customer_id,
    CAST($3 AS DOUBLE) AS amount,
    CAST($4 AS DATE) AS sale_date
FROM FILES(
    "path" = "s3://landing/sales_day1.csv",
    "format" = "csv",
    "csv.column_separator" = ",",
    "csv.skip_header" = "1",
    "aws.s3.access_key" = "admin",
    "aws.s3.secret_key" = "password",
    "aws.s3.endpoint" = "http://minio:9000",
    "aws.s3.enable_ssl" = "false",
    "aws.s3.enable_path_style_access" = "true",
    "aws.s3.region" = "us-east-1"
);

SELECT COUNT(*) AS day1_rows FROM demo.sales.sales;
SELECT * FROM demo.sales.sales ORDER BY sale_id;
