{{
    config(
        materialized='view',
        schema='staging'
    )
}}

-- stg_order_items.sql
-- -------------------
-- Staging model for the raw order_items table. One row per item per order.
-- An order can contain multiple items from different sellers.
--
-- Joins:
--   stg_order_items.order_id    → stg_orders.order_id
--   stg_order_items.product_id  → stg_products.product_id
--   stg_order_items.seller_id   → stg_sellers.seller_id
--
-- Primary key: composite of order_id + order_item_id
--
-- Changes from raw:
--   - SHIPPING_LIMIT_DATE cast from TEXT to TIMESTAMP and renamed with _at suffix
--   - No other type casting needed — PRICE and FREIGHT_VALUE already FLOAT

with source as (

    select * from {{ source('olist', 'order_items') }}

),

renamed as (

    select
        -- Composite primary key: one order can have multiple items
        order_id,
        order_item_id,

        -- Foreign keys
        product_id,   -- joins to stg_products
        seller_id,    -- joins to stg_sellers

        -- Timestamp — cast from TEXT to TIMESTAMP
        -- Deadline by which the seller must hand the item to the carrier
        try_to_timestamp(shipping_limit_date) as shipping_limit_at,

        -- Financials — already FLOAT in raw, no casting needed
        price,          -- item price in BRL, excluding freight
        freight_value   -- freight cost in BRL for this item

    from source

)

select * from renamed
