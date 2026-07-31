{{
    config(
        materialized='view',
        schema='staging'
    )
}}

-- stg_sellers.sql
-- ---------------
-- Staging model for the raw sellers table. One row per seller.
-- Sellers are the merchants who list products on the Olist marketplace.
--
-- Joins:
--   stg_order_items.seller_id → stg_sellers.seller_id
--   stg_sellers.zip_code_prefix → stg_geolocation.zip_code_prefix (for seller location)
--
-- Changes from raw:
--   - Redundant SELLER_ prefix dropped from city, state, zip_code_prefix
--   - No type casting needed — all columns are already correct types

with source as (

    select * from {{ source('olist', 'sellers') }}

),

renamed as (

    select
        -- Primary key
        seller_id,

        -- Location fields — joins to stg_geolocation for lat/lng coordinates
        seller_zip_code_prefix as zip_code_prefix,
        seller_city            as city,
        seller_state           as state

    from source

)

select * from renamed
