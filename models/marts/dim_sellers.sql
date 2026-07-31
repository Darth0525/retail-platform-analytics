{{
    config(
        materialized='table',
        schema='marts'
    )
}}

-- dim_sellers.sql
-- ---------------
-- One row per seller registered on the Olist marketplace.
-- stg_sellers is already unique on seller_id — no deduplication needed.
--
-- City and state sourced from dim_geolocation, not stg_sellers:
--   Raw seller city/state has spelling variations in source data.
--   Geolocation-derived values are standardized via MODE() across thousands
--   of entries per zip, making them more reliable for grouping in reports.
--
-- Joins:
--   stg_sellers.zip_code_prefix → dim_geolocation.zip_code_prefix

with sellers as (

    select * from {{ ref('stg_sellers') }}

),

geolocation as (

    select * from {{ ref('dim_geolocation') }}

),

final as (

    select
        -- Primary key
        s.seller_id,

        -- Location — sourced from geolocation for standardized spelling
        s.zip_code_prefix,
        g.city,
        g.state

    from sellers s
    left join geolocation g on s.zip_code_prefix = g.zip_code_prefix

)

select * from final
