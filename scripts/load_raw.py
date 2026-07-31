"""
load_raw.py
-----------
Reads each of the 9 Olist CSV files from the local data/ folder and loads
them into the RAW schema in Snowflake. Each CSV becomes one table.

This is the first step in the pipeline:
  data/ (local CSVs) → Snowflake RAW schema → dbt models

Authentication: RSA key-pair (bypasses MFA for programmatic access).
The private key lives at ~/.ssh/snowflake_rsa_key.p8 and its path is
stored in .env as SNOWFLAKE_PRIVATE_KEY_PATH.

Usage:
  python scripts/load_raw.py

Credentials are loaded automatically from the .env file in the project root.
You do NOT need to run `source .env` manually before running this script.
"""

import os
from pathlib import Path

import pandas as pd
import snowflake.connector
from snowflake.connector.pandas_tools import write_pandas
from dotenv import load_dotenv

# cryptography is installed as a dependency of snowflake-connector-python.
# We use it to read and parse the RSA private key file into the format
# that the Snowflake connector expects.
from cryptography.hazmat.primitives.serialization import (
    load_pem_private_key,  # parses a PEM-format private key file
    Encoding,              # specifies the output encoding format (DER in our case)
    PrivateFormat,         # specifies the key format (PKCS8 — what Snowflake requires)
    NoEncryption,          # our private key has no passphrase, so no encryption needed
)


# ---------------------------------------------------------------------------
# Load credentials from .env
# ---------------------------------------------------------------------------
# Path(__file__) is the absolute path to this script (scripts/load_raw.py).
# .parent        → scripts/
# .parent.parent → project root (retail-platform-analytics/)
# load_dotenv reads each line of .env and adds it to os.environ automatically.
load_dotenv(Path(__file__).parent.parent / ".env")


# ---------------------------------------------------------------------------
# Snowflake connection settings (read from .env)
# ---------------------------------------------------------------------------
# os.environ["KEY"] raises a KeyError immediately if the variable is missing.
# This is intentional — better to fail fast with a clear error than to get
# a confusing Snowflake authentication error later.
SNOWFLAKE_ACCOUNT = os.environ["SNOWFLAKE_ACCOUNT"]          # e.g. dr92237.us-east-2.aws
SNOWFLAKE_USER = os.environ["SNOWFLAKE_USER"]                # your Snowflake username
SNOWFLAKE_PRIVATE_KEY_PATH = os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"]  # path to RSA private key

# os.environ.get("KEY", default) returns the default if the key is missing.
# These have sensible defaults so they're optional in .env.
SNOWFLAKE_DATABASE = os.environ.get("SNOWFLAKE_DATABASE", "RETAIL_ANALYTICS")
SNOWFLAKE_WAREHOUSE = os.environ.get("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH")

# The schema inside the database where raw tables will be created.
# All 9 CSVs land here before dbt transforms them.
RAW_SCHEMA = "RAW"


# ---------------------------------------------------------------------------
# Data directory
# ---------------------------------------------------------------------------
# Always resolves to retail-platform-analytics/data/ regardless of where you
# run the script from — relative to the script file, not the shell's CWD.
DATA_DIR = Path(__file__).parent.parent / "data"


# ---------------------------------------------------------------------------
# CSV → Snowflake table mapping
# ---------------------------------------------------------------------------
# Keys: exact CSV filenames as downloaded from Kaggle.
# Values: Snowflake table names in the RAW schema.
CSV_TABLE_MAP = {
    "olist_customers_dataset.csv": "customers",
    "olist_geolocation_dataset.csv": "geolocation",
    "olist_order_items_dataset.csv": "order_items",
    "olist_order_payments_dataset.csv": "order_payments",
    "olist_order_reviews_dataset.csv": "order_reviews",
    "olist_orders_dataset.csv": "orders",
    "olist_products_dataset.csv": "products",
    "olist_sellers_dataset.csv": "sellers",
    "product_category_name_translation.csv": "product_category_name_translation",
}


def load_private_key(key_path: str) -> bytes:
    """
    Reads the RSA private key file and converts it to DER bytes format,
    which is what the Snowflake Python connector expects for key-pair auth.

    Why DER and not PEM?
    - PEM is the human-readable format (the file with -----BEGIN PRIVATE KEY-----)
    - DER is the binary format that Snowflake's connector accepts as input
    - We read PEM from disk, parse it, then serialize to DER in memory

    Args:
        key_path: Path to the .p8 private key file (e.g. ~/.ssh/snowflake_rsa_key.p8)

    Returns:
        Private key as DER-encoded bytes, ready to pass to snowflake.connector.connect()
    """
    # Read the raw bytes of the private key file from disk
    with open(key_path, "rb") as f:
        pem_data = f.read()

    # Parse the PEM file into a private key object.
    # password=None because we generated the key without a passphrase (-nocrypt flag).
    private_key = load_pem_private_key(pem_data, password=None)

    # Serialize the key object back out as DER-encoded bytes.
    # PKCS8 is the key format Snowflake requires — it's a standard that wraps
    # the raw RSA key with metadata about the algorithm used.
    return private_key.private_bytes(
        encoding=Encoding.DER,
        format=PrivateFormat.PKCS8,
        encryption_algorithm=NoEncryption(),
    )


def get_connection():
    """
    Opens and returns a Snowflake connection using RSA key-pair authentication.

    Key-pair auth works by:
    1. Snowflake challenges your client to prove it holds the private key
    2. Your client signs the challenge with the private key
    3. Snowflake verifies the signature using the public key it has on file
    4. No password is ever transmitted — this is why it bypasses MFA

    The connection is set to use the RAW schema by default so all table
    operations happen there without needing to prefix every SQL statement.
    """
    private_key_bytes = load_private_key(SNOWFLAKE_PRIVATE_KEY_PATH)

    return snowflake.connector.connect(
        account=SNOWFLAKE_ACCOUNT,
        user=SNOWFLAKE_USER,
        private_key=private_key_bytes,   # key-pair auth — replaces password=
        database=SNOWFLAKE_DATABASE,
        warehouse=SNOWFLAKE_WAREHOUSE,
        schema=RAW_SCHEMA,
    )


def ensure_database_and_schema(cursor):
    """
    Creates the database and RAW schema if they don't already exist.

    IF NOT EXISTS makes these statements safe to run multiple times —
    they won't overwrite or error if the objects already exist.
    """
    # Create the project database (Snowflake trial doesn't include this by default)
    cursor.execute(f"CREATE DATABASE IF NOT EXISTS {SNOWFLAKE_DATABASE}")

    # Create the RAW schema inside that database
    cursor.execute(f"CREATE SCHEMA IF NOT EXISTS {SNOWFLAKE_DATABASE}.{RAW_SCHEMA}")

    # Set the active database and schema for all subsequent SQL in this session
    cursor.execute(f"USE DATABASE {SNOWFLAKE_DATABASE}")
    cursor.execute(f"USE SCHEMA {RAW_SCHEMA}")


def load_csv(conn, csv_path: Path, table_name: str) -> int:
    """
    Reads one CSV file into a pandas DataFrame and writes it to Snowflake.

    Args:
        conn:       Active Snowflake connection
        csv_path:   Full Path object pointing to the CSV file
        table_name: Target table name in Snowflake (RAW schema)

    Returns:
        Number of rows loaded
    """
    print(f"  Loading {csv_path.name} → {table_name.upper()}...")

    # Read the CSV into a pandas DataFrame.
    # low_memory=False tells pandas to read the full file before inferring column
    # types — avoids mixed-type warnings that can occur on large files.
    df = pd.read_csv(csv_path, low_memory=False)

    # Snowflake stores column names in uppercase internally.
    # We uppercase them here to match that convention explicitly.
    df.columns = [col.upper() for col in df.columns]

    # write_pandas is Snowflake's optimised bulk loader for DataFrames.
    # It uses Snowflake's internal COPY INTO mechanism under the hood,
    # which is much faster than inserting rows one at a time.
    #
    # auto_create_table=True → creates the table if it doesn't exist yet,
    #                          inferring column types from the DataFrame
    # overwrite=True         → drops and recreates the table on each run,
    #                          ensuring a clean load every time
    success, nchunks, nrows, _ = write_pandas(
        conn,
        df,
        table_name=table_name.upper(),
        auto_create_table=True,
        overwrite=True,
    )

    print(f"  ✓ {nrows:,} rows loaded into {table_name.upper()}")
    return nrows


def main():
    """
    Entry point. Connects to Snowflake, sets up the schema, then iterates
    through CSV_TABLE_MAP loading each file. Skips files not found in data/.
    """
    print(f"Connecting to Snowflake ({SNOWFLAKE_ACCOUNT})...")
    conn = get_connection()

    # cursor() lets us execute raw SQL statements (CREATE DATABASE, USE SCHEMA, etc.)
    # write_pandas uses the connection object directly, not the cursor.
    cursor = conn.cursor()

    print(f"Setting up database and schema: {SNOWFLAKE_DATABASE}.{RAW_SCHEMA}")
    ensure_database_and_schema(cursor)

    total_rows = 0

    for csv_filename, table_name in CSV_TABLE_MAP.items():
        csv_path = DATA_DIR / csv_filename

        # Skip gracefully if a file is missing rather than crashing the whole run
        if not csv_path.exists():
            print(f"  SKIP {csv_filename} (not found in data/)")
            continue

        rows = load_csv(conn, csv_path, table_name)
        total_rows += rows

    # Always close cursor and connection when done to free up Snowflake resources
    cursor.close()
    conn.close()

    print(f"\nDone. {total_rows:,} total rows loaded into {SNOWFLAKE_DATABASE}.{RAW_SCHEMA}.")


# This block ensures main() only runs when the script is executed directly.
# If another Python file imports this module, main() will NOT run automatically.
if __name__ == "__main__":
    main()
