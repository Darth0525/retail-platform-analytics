{{
    config(
        materialized='view',
        schema='staging'
    )
}}

-- stg_customers.sql
-- -----------------
-- Staging model for the raw customers table.
--
-- Important: this is NOT a customer dimension. The raw customers table has
-- one row per order, not per real customer — customer_id is unique per order,
-- while customer_unique_id is the true customer identifier across orders.
-- A proper dim_customers will be built in the marts layer using customer_unique_id.
--
-- Changes from raw:
--   - Redundant CUSTOMER_ prefix dropped from city, state, zip_code_prefix
--   - No type casting needed — all columns are already correct types

with source as (

    select * from {{ source('olist', 'customers') }}

),

renamed as (

    select
        -- Primary key — unique per order (not per real customer)
        customer_id,

        -- True unique customer identifier across all orders.
        -- Use this for customer-level analysis and counting distinct customers.
        customer_unique_id,

        -- Location fields — CUSTOMER_ prefix dropped as it is implied by the model name
        customer_zip_code_prefix as zip_code_prefix,  -- joins to stg_geolocation.zip_code_prefix
        customer_city            as city,
        customer_state           as state

    from source

)

select * from renamed
