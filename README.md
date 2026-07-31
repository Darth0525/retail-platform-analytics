# Retail Platform Analytics

An analytics engineering project built on the [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (~100k orders, 2016–2018). Demonstrates dbt + Snowflake best practices across a static historical dataset — layered transformations, data quality testing, and analytics-ready mart tables in a dev environment.

**Interactive dbt docs:** [https://darth0525.github.io/retail-platform-analytics](https://darth0525.github.io/retail-platform-analytics)

## Tech Stack

| Tool | Purpose |
|---|---|
| **Snowflake** | Cloud data warehouse |
| **dbt** | SQL transformations, testing, documentation |
| **Python** | Raw data ingestion (CSV → Snowflake) |
| **Kaggle API** | Dataset download |
| **GitHub** | Version control, feature branch workflow |

---

## Architecture

```
Kaggle CSVs
    │
    ▼
scripts/load_raw.py
    │  (Python + Snowflake connector)
    ▼
RAW schema (Snowflake)
    │  9 raw tables, 1.55M rows total
    ▼
┌─────────────────────────────────────────────┐
│  STAGING layer  (dev_staging schema)        │
│  stg_orders, stg_customers, stg_sellers,    │
│  stg_products, stg_product_categories,      │
│  stg_order_items, stg_order_payments,       │
│  stg_order_reviews, stg_geolocation         │
│                                             │
│  • Column renames and type casts            │
│  • 1:1 with raw tables, no business logic   │
│  • 57 generic tests + 9 singular tests      │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│  INTERMEDIATE layer  (dev_intermediate)     │
│  int_orders, int_order_reviews,             │
│  int_order_payments, int_geolocation_by_zip │
│                                             │
│  • Deduplication and data quality flags     │
│  • Joins across staging models              │
│  • 28 generic tests + 2 singular tests      │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│  MARTS layer  (dev_marts schema)            │
│                                             │
│  Dimensions:  dim_customers, dim_sellers,   │
│               dim_products, dim_geolocation │
│                                             │
│  Facts:       fct_orders, fct_order_items   │
│                                             │
│  Marts:       mart_customer_summary,        │
│               mart_seller_performance       │
│                                             │
│  • Analytics-ready tables                  │
│  • 46 generic tests + 8 singular tests      │
└─────────────────────────────────────────────┘
```

**Total: 21 models, 140 tests (133 pass, 7 known warns)**

---

## Dataset

The [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) contains anonymized orders from Brazil's largest department store marketplace between 2016 and 2018.

| Table | Rows | Description |
|---|---|---|
| orders | 99,441 | One row per order with status and timestamps |
| order_items | 112,650 | Line items — product, seller, price, freight |
| order_payments | 103,886 | Payment methods and values per order |
| order_reviews | 100,000 | Customer satisfaction scores and comments |
| customers | 99,441 | Customer identity and location |
| sellers | 3,095 | Seller identity and location |
| products | 32,951 | Product attributes and dimensions |
| product_category_name_translation | 71 | Portuguese → English category names |
| geolocation | 1,000,163 | Zip code → coordinates mapping |

---

## Business Questions Answered

**Customer analysis** — using `mart_customer_summary` + `dim_customers`
- Who are the highest-value customers by total spend?
- What is the repeat purchase rate across the platform?
- Which Brazilian states have the most active customers?
- How does average review score vary by customer location?

**Seller performance** — using `mart_seller_performance` + `dim_sellers`
- Which sellers generate the most revenue?
- Which sellers have the fastest average delivery times?
- Which sellers have the highest customer satisfaction scores?
- Which sellers deliver on time most consistently?
- How does seller location correlate with delivery performance?

**Order analysis** — using `fct_orders` + `fct_order_items`
- What share of orders are delivered on time?
- What is the average delivery time from purchase to delivery?
- Which product categories drive the most revenue?
- How does payment method (credit card, boleto, voucher) vary by order value?
- What is the relationship between product weight and freight cost?

**On a live dataset, additional time-series analysis would include:**
- Monthly/quarterly revenue trends
- Customer retention cohorts
- Seasonal demand patterns
- `total_orders_last_12m`, `total_spend_last_12m`, `has_order_in_last_quarter` flags per customer

---

## Data Quality Findings

One of the key outcomes of this project was a thorough audit of source data quality. All issues are documented in staging tests (`severity: warn`) and handled in the intermediate layer.

| Issue | Count | Layer handled |
|---|---|---|
| Duplicate `review_id`s across orders | 789 review_ids | `int_order_reviews` — dedup on review_id |
| Orders with multiple reviews | 547 orders | `int_order_reviews` — dedup on order_id |
| Bad delivery sequences (customer before carrier) | 23 orders | `int_orders` — `is_valid_delivery` flag |
| Incomplete payment sequences (missing rows) | 80 orders | `int_order_payments` — `has_incomplete_payment_sequence` flag |
| Payment value mismatch vs item totals | 576 orders | `int_order_payments` — `has_payment_value_mismatch` flag |
| `not_defined` payment type | 3 rows | `int_order_payments` — `has_not_defined_payment` flag |
| Zero installments on credit card rows | 2 rows | `int_order_payments` — treated as 1 |
| Order with no payment record | 1 order | `mart_customer_summary` — COALESCE to 0 |
| Non-unique zip codes in geolocation | 1M → 19K rows | `int_geolocation_by_zip` — MODE dedup |

---

## Project Structure

```
retail-platform-analytics/
├── models/
│   ├── staging/
│   │   ├── _sources.yml          # Raw table registration
│   │   ├── _stg_models.yml       # Staging docs and tests
│   │   └── stg_*.sql             # 9 staging models
│   ├── intermediate/
│   │   ├── _int_models.yml       # Intermediate docs and tests
│   │   └── int_*.sql             # 4 intermediate models
│   └── marts/
│       ├── _marts_models.yml     # Marts docs and tests
│       ├── dim_*.sql             # 4 dimension tables
│       ├── fct_*.sql             # 2 fact tables
│       └── mart_*.sql            # 2 mart tables
├── tests/
│   └── singular/                 # 14 custom SQL tests
├── scripts/
│   └── load_raw.py               # CSV → Snowflake ingestion
├── dbt_project.yml
├── requirements.txt
└── README.md
```

---

## How to Run

### Prerequisites
- Python 3.11+ via pyenv
- Snowflake account with a warehouse and database
- Kaggle account with API key at `~/.kaggle/kaggle.json`
- dbt profile at `~/.dbt/profiles.yml` (see `profiles.yml.template`)

### Setup

```bash
# Clone the repo
git clone https://github.com/Darth0525/retail-platform-analytics.git
cd retail-platform-analytics

# Create virtualenv and install dependencies
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Add Snowflake credentials to .env (see .env.example)
cp .env.example .env
```

### Load raw data

```bash
# Download dataset from Kaggle and load into Snowflake RAW schema
python scripts/load_raw.py
```

### Run dbt

```bash
# Verify Snowflake connection
dbt debug

# Build all models
dbt run

# Run all tests
dbt test

# Build and test in one command
dbt build

# Generate and serve documentation locally
dbt docs generate
dbt docs serve

# Hosted docs (GitHub Pages)
# https://darth0525.github.io/retail-platform-analytics
```

### Run a specific layer

```bash
dbt run --select staging
dbt run --select intermediate
dbt run --select marts
```
