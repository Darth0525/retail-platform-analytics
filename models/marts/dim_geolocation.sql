{{
    config(
        materialized='table',
        schema='marts'
    )
}}

-- dim_geolocation.sql
-- -------------------
-- Dimension table mapping Brazilian zip code prefixes to city and state.
-- One row per zip_code_prefix — the single authoritative lookup for location
-- data used across dim_customers, dim_sellers, and fct_orders.
--
-- Source: int_geolocation_by_zip, which deduplicates stg_geolocation from
-- 1,000,163 rows to 19,015 unique zip code prefixes using MODE(city/state)
-- to standardize spelling variations in the raw data.
--
-- Why a dedicated dim table instead of joining int_geolocation_by_zip directly:
--   Three models need zip → city/state mapping (dim_customers, dim_sellers,
--   fct_orders). Centralizing here means one place to maintain the lookup
--   and consistent city/state values across all downstream models.
--
-- Used by:
--   dim_customers — customer last known location
--   dim_sellers   — seller location
--   fct_orders    — order delivery location

with source as (

    select * from {{ ref('int_geolocation_by_zip') }}

)

select
    -- Primary key
    zip_code_prefix,

    -- Standardized location — derived via MODE() in int_geolocation_by_zip
    city,
    state

from source
