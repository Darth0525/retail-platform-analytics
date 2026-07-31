{{
    config(
        materialized='view',
        schema='staging'
    )
}}

-- stg_orders.sql
-- --------------
-- Staging model for the raw orders table. One row per order.
-- This is the central table of the Olist dataset — all other staging
-- models eventually join back to orders via order_id.
--
-- Changes from raw:
--   - Columns renamed to consistent snake_case
--   - All timestamp columns cast from TEXT to TIMESTAMP
--   - estimated_delivery_date cast to DATE (time component is always 00:00:00)

with source as (

    -- Pull all rows from the raw orders table.
    -- source('olist', 'orders') resolves to RETAIL_ANALYTICS.RAW.ORDERS.
    -- Using source() instead of a hardcoded path lets dbt track lineage
    -- and warn us if the source table stops being updated.
    select * from {{ source('olist', 'orders') }}

),

renamed as (

    select
        -- Primary key
        order_id,

        -- Foreign key — joins to stg_customers.customer_id (1-to-1 with orders).
        -- Note: the customers raw table is NOT a customer dimension — it is an
        -- order-customer lookup with one row per order, not per real customer.
        -- customer_unique_id in stg_customers is the true customer identifier.
        -- A proper customer dimension (dim_customers) will be built in the marts layer.
        customer_id,

        -- Order lifecycle status
        -- Values: delivered, shipped, canceled, unavailable,
        --         invoiced, processing, created, approved
        order_status as status,

        -- Timestamps — cast from TEXT to TIMESTAMP using TRY_TO_TIMESTAMP.
        -- TRY_TO_TIMESTAMP returns NULL instead of throwing an error if the
        -- value cannot be parsed, which is safer given some columns are nullable.
        try_to_timestamp(order_purchase_timestamp)     as purchased_at,
        try_to_timestamp(order_approved_at)            as approved_at,
        try_to_timestamp(order_delivered_carrier_date) as delivered_to_carrier_at,
        try_to_timestamp(order_delivered_customer_date) as delivered_to_customer_at,

        -- Cast to DATE (not TIMESTAMP) — the time component is always 00:00:00
        -- in the source data, meaning only the date is meaningful here.
        try_to_date(order_estimated_delivery_date)     as estimated_delivery_date

    from source

)

select * from renamed
