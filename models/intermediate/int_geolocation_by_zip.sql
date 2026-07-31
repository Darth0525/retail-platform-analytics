{{
    config(
        materialized='view',
        schema='intermediate'
    )
}}

-- int_geolocation_by_zip.sql
-- --------------------------
-- Deduplicates stg_geolocation from one row per delivery coordinate entry
-- to one row per zip_code_prefix.
--
-- Why deduplication is needed:
--   stg_geolocation has 1,000,163 rows but only 19,015 unique zip code prefixes.
--   Each prefix averages 52.6 rows (max 1,146). Multiple rows exist because
--   Olist recorded exact GPS coordinates at each delivery event, then grouped
--   by zip code prefix. The coordinates represent individual delivery points
--   within a postal area, not meaningful zip-level geography.
--
-- Why lat/lng is excluded:
--   Coordinates are delivery-event-level data, not zip-code-level data.
--   For our downstream analysis (customer and seller location by city/state),
--   city and state are sufficient. Averaging hundreds of delivery GPS points
--   into a zip centroid adds noise without analytical value.
--
-- Deduplication strategy:
--   MODE(city) and MODE(state) — most frequent value per zip code prefix.
--   Handles spelling variations in source data (e.g. mixed accents, casing).
--
-- Output: 19,015 rows — one per unique zip_code_prefix.
-- Used by: dim_customers and dim_sellers to enrich with location data.

with source as (

    select * from {{ ref('stg_geolocation') }}

),

deduped as (

    select
        -- Primary key after deduplication
        zip_code_prefix,

        -- Most frequent city name for this zip — handles spelling variations in source
        mode(city)  as city,

        -- Most frequent state for this zip — should be consistent but MODE handles exceptions
        mode(state) as state

    from source
    group by zip_code_prefix

)

select * from deduped
