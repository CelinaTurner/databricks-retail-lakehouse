# Retail Lakehouse — Databricks + dbt

An end-to-end lakehouse on the public **UCI Online Retail II** dataset, built on
Databricks with a medallion architecture, transformed and tested with **dbt**,
orchestrated as code with a **Databricks Asset Bundle**, and validated in
**GitHub Actions**.

The point of the project is to show a complete, reproducible data platform
rather than a single notebook of analysis: ingestion, transformation, data
quality testing, governance, orchestration, and CI all in version control.

## Architecture

```
                      ┌─────────────────────────────────────────────┐
                      │            Unity Catalog (governance)         │
                      │   catalog: retail_portfolio                   │
                      └─────────────────────────────────────────────┘
 CSV ─▶ Auto Loader ─▶ bronze.online_retail ─▶ dbt ─▶ silver.* ─▶ dbt ─▶ gold.*
 (volume)  (incremental)     (raw)                 (clean/test)      (marts) ─▶ SQL dashboard + alert

         orchestrated by a Databricks Job (Asset Bundle) ·  validated by GitHub Actions
```

| Layer | What | Tool |
|-------|------|------|
| Ingest | Incremental CSV → `bronze.online_retail` | Auto Loader (`src/01_ingest_bronze.py`) |
| Transform (Silver) | Clean, type, dedupe, drop cancellations | dbt view `stg_online_retail` |
| Transform (Gold) | `fct_sales`, `dim_customers` (RFM), `revenue_by_country` | dbt tables |
| Test | not_null / unique / relationships / accepted_range | dbt + dbt_utils |
| Govern | Catalog + schemas (bronze/silver/gold) | Unity Catalog |
| Orchestrate | Job: ingest → `dbt build`, scheduled | Databricks Asset Bundle (`databricks.yml`) |
| CI | Parse on PR, build-and-test on demand | GitHub Actions (`.github/workflows/dbt.yml`) |

## Prerequisites

- A Databricks workspace (Free Edition is fine) with a serverless SQL warehouse.
- The Online Retail II CSV: https://archive.ics.uci.edu/dataset/502/online+retail+ii
- Python 3.11+ and the Databricks CLI (for the bundle).

## 1. Load the bronze layer

Import `src/01_ingest_bronze.py` as a notebook in your workspace and run it once.
It creates the `retail_portfolio` catalog, the bronze/silver/gold schemas, and a
`bronze.landing` volume, then prints the volume path. Upload the CSV there
(Catalog Explorer → … → landing → Upload), and re-run — Auto Loader ingests it
into `bronze.online_retail`.

## 2. Run dbt locally

```bash
cd dbt
python -m venv .venv && source .venv/bin/activate
pip install dbt-databricks

# Connection values from the SQL warehouse "Connection details" tab.
# The token is a personal access token — keep it out of any committed file.
export DBT_HOST="dbc-xxxxxxxx-xxxx.cloud.databricks.com"
export DBT_HTTP_PATH="/sql/1.0/warehouses/xxxxxxxxxxxxxxxx"
export DBT_TOKEN="dapi....."
export DBT_PROFILES_DIR="$PWD"

cp profiles.example.yml profiles.yml
dbt deps
dbt build          # runs all models, then all tests
dbt docs generate  # optional: lineage + docs site
```

`dbt build` materializes `silver.stg_online_retail` (view), the three `gold`
marts (tables), and runs every test. A passing run is a good screenshot for the
portfolio.

## 3. Orchestrate as a job (Asset Bundle)

```bash
databricks bundle validate
databricks bundle deploy -t dev \
  --var="workspace_host=https://dbc-xxxx.cloud.databricks.com" \
  --var="warehouse_id=xxxxxxxxxxxxxxxx"
databricks bundle run retail_medallion -t dev
```

This creates a `retail_medallion_pipeline` job with two tasks — bronze ingestion
then `dbt build` — visible (and screenshot-able) under **Workflows / Jobs**.

## 4. CI

Add `DBT_HOST`, `DBT_HTTP_PATH`, and `DBT_TOKEN` as GitHub Actions secrets. Pull
requests run a cheap `dbt parse` (no warehouse, no quota). The full build + test
runs on demand via **Actions → dbt → Run workflow**.

## Notes

- `customer_id` and `unit_price` come from the Online Retail II columns
  `Customer ID` and `Price`; `stg_online_retail` normalizes these names. If you
  use the older "Online Retail" file, adjust the column names in that model.
- Free Edition has a daily compute quota; if a run pauses, it resumes next day
  with data intact.
