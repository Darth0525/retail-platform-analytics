"""
Shared Snowflake connection utility for all notebooks.
Reads credentials from the .env file at the project root.
Returns a pandas DataFrame for any SQL query.
"""

import os
import warnings
from pathlib import Path
import pandas as pd
import snowflake.connector
from dotenv import load_dotenv

# Load .env from project root (one level up from notebooks/)
load_dotenv(Path(__file__).parent.parent / ".env")

SCHEMA = "DEV_MARTS"
DATABASE = os.environ["SNOWFLAKE_DATABASE"]


def _get_connection() -> snowflake.connector.SnowflakeConnection:
    """Open a Snowflake connection using credentials from .env."""
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        private_key_file=os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"],
        role=os.environ.get("SNOWFLAKE_ROLE", "ACCOUNTADMIN"),
        database=DATABASE,
        schema=SCHEMA,
        warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
    )


def query(sql: str) -> pd.DataFrame:
    """Run a SQL query and return the result as a DataFrame."""
    with _get_connection() as conn:
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            return pd.read_sql(sql, conn)
