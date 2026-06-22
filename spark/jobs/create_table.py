from pyspark.sql import SparkSession

spark = (
    SparkSession.builder
    .appName("create-table")

    .config(
        "spark.sql.catalog.nessie",
        "org.apache.iceberg.spark.SparkCatalog"
    )
    .config(
        "spark.sql.catalog.nessie.catalog-impl",
        "org.apache.iceberg.nessie.NessieCatalog"
    )
    .config(
        "spark.sql.catalog.nessie.uri",
        "http://nessie:19120/api/v1"
    )
    .config(
        "spark.sql.catalog.nessie.warehouse",
        "s3a://warehouse"
    )
    .config(
        "spark.sql.catalog.nessie.s3.endpoint",
        "http://minio:9000"
    )
    .config(
        "spark.sql.catalog.nessie.s3.access-key-id",
        "admin"
    )
    .config(
        "spark.sql.catalog.nessie.s3.secret-access-key",
        "password123"
    )
    .getOrCreate()
)

spark.sql("""
CREATE TABLE IF NOT EXISTS nessie.demo.sales (
    sale_id BIGINT,
    customer_id BIGINT,
    amount DOUBLE,
    sale_date DATE
)
USING iceberg
PARTITIONED BY (days(sale_date))
TBLPROPERTIES (
    'format-version'='2'
)
""")