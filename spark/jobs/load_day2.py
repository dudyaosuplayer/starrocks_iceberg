from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()

df = spark.read.option(
    "header",
    True
).csv("/data/sales_day2.csv")

df.writeTo(
    "nessie.demo.sales"
).append()