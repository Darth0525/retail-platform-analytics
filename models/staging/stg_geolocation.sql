{{
    config(
        materialized='view',
        schema='staging'
    )
}}

-- stg_geolocation.sql
-- -------------------
-- Staging model for the raw geolocation table. Maps Brazilian zip code prefixes
-- to latitude, longitude, city, and state.
--
-- Important: zip_code_prefix is NOT unique in this table — one zip code prefix
-- can have multiple rows with slightly different coordinates. When joining to
-- customers or sellers, aggregate first (e.g. AVG lat/lng) or use QUALIFY to
-- pick one row per zip code prefix. This is handled in the intermediate layer.
--
-- Largest table in the project at 1,000,163 rows.
--
-- Joins (done in intermediate layer, not directly):
--   stg_customers.zip_code_prefix → stg_geolocation.zip_code_prefix
--   stg_sellers.zip_code_prefix   → stg_geolocation.zip_code_prefix
--
-- Changes from raw:
--   - Redundant GEOLOCATION_ prefix dropped from all columns
--   - LAT/LNG abbreviated names expanded to latitude/longitude for readability
--   - No type casting needed — FLOAT columns already correct types

with source as (

    select * from {{ source('olist', 'geolocation') }}

),

renamed as (

    select
        -- Zip code prefix — NOT unique, one prefix can have multiple coordinate entries
        geolocation_zip_code_prefix as zip_code_prefix,

        -- Coordinates — already FLOAT in raw, no casting needed
        geolocation_lat             as latitude,
        geolocation_lng             as longitude,

        -- Location names
        geolocation_city            as city,
        geolocation_state           as state

    from source

)

select * from renamed
