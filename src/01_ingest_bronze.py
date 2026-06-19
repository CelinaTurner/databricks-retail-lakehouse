# Databricks notebook source
# MAGIC %md
# MAGIC # Bronze ingestion — Online Retail II via Auto Loader
# MAGIC
# MAGIC Sets up the Unity Catalog namespace and a landing volume, then uses
# MAGIC Auto Loader (`cloudFiles`) to incrementally ingest any CSV files dropped
# MAGIC into the volume into the `bronze.online_retail` table.
# MAGIC
# MAGIC **One-time data step:** download the "Online Retail II" CSV from the UCI
# MAGIC repository (https://archive.ics.uci.edu/dataset/502/online+retail+ii) and
# MAGIC upload it into the landing volume printed below (Catalog Explorer →
# MAGIC retail_portfolio → bronze → landing → Upload). Re-running this notebook
# MAGIC only ingests files that are new since the last run.

# COMMAND ----------

CATALOG = "retail_portfolio"
LANDING = f"/Volumes/{CATALOG}/bronze/landing"

spark.sql(f"CREATE CATALOG IF NOT EXISTS {CATALOG}")
spark.sql(f"CREATE SCHEMA  IF NOT EXISTS {CATALOG}.bronze")
spark.sql(f"CREATE SCHEMA  IF NOT EXISTS {CATALOG}.silver")
spark.sql(f"CREATE SCHEMA  IF NOT EXISTS {CATALOG}.gold")
spark.sql(f"CREATE VOLUME  IF NOT EXISTS {CATALOG}.bronze.landing")

print(f"Upload the Online Retail II CSV here: {LANDING}")

# COMMAND ----------

# Auto Loader: incremental, schema-tracked ingestion of CSVs in the volume.
bronze_stream = (
    spark.readStream
        .format("cloudFiles")
        .option("cloudFiles.format", "csv")
        .option("header", "true")
        .option("cloudFiles.inferColumnTypes", "true")
        .option("cloudFiles.schemaLocation", f"{LANDING}/_schema")
        .load(LANDING)
)

# COMMAND ----------
# Normalize column names: replace any Delta-illegal char with underscore.
import re
for c in bronze_stream.columns:
    bronze_stream = bronze_stream.withColumnRenamed(
        c, re.sub(r"[ ,;{}()\n\t=]", "_", c)
    )
# trigger=availableNow processes all currently-available files then stops,
# which makes this notebook safe to run as a scheduled batch task.
(
    bronze_stream.writeStream
        .option("checkpointLocation", f"{LANDING}/_checkpoint")
        .option("mergeSchema", "true")
        .option("delta.columnMapping.mode", "name")
        .trigger(availableNow=True)
        .toTable(f"{CATALOG}.bronze.online_retail")
        .awaitTermination()
)

# COMMAND ----------

display(spark.sql(f"SELECT COUNT(*) AS rows FROM {CATALOG}.bronze.online_retail"))
