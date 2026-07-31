{{
    config(
        materialized='table',
        schema='marts'
    )
}}

-- fct_order_items.sql
-- -------------------
-- One row per item per order. Grain is order_id + order_item_id (composite PK).
-- Enriches stg_order_items with product category and seller location.
--
-- An order can have multiple items from different sellers — this table
-- captures the line-item detail behind each order in fct_orders.
--
-- Key use cases:
--   - Revenue analysis by product category
--   - Freight cost vs product weight/size analysis
--   - Seller performance by city/state
--   - Product-level sales volume
--
-- Joins:
--   stg_order_items.product_id → dim_products.product_id
--   stg_order_items.seller_id  → dim_sellers.seller_id

with order_items as (

    select * from {{ ref('stg_order_items') }}

),

products as (

    -- Only need category for this fact table — full product attributes in dim_products
    select
        product_id,
        category_name
    from {{ ref('dim_products') }}

),

sellers as (

    -- Only need location for this fact table — full seller attributes in dim_sellers
    select
        seller_id,
        city  as seller_city,
        state as seller_state
    from {{ ref('dim_sellers') }}

),

final as (

    select
        -- Composite primary key
        oi.order_id,
        oi.order_item_id,

        -- Foreign keys
        oi.product_id,                          -- joins to dim_products
        oi.seller_id,                           -- joins to dim_sellers

        -- Shipping deadline
        oi.shipping_limit_at,

        -- Pricing
        oi.price,                               -- item price in BRL excluding freight
        oi.freight_value,                       -- freight cost in BRL for this item
        oi.price + oi.freight_value as total_item_value,  -- total cost of this line item

        -- Product category — English name from dim_products
        p.category_name,                        -- null if product has no category in source

        -- Seller location — for regional seller performance analysis
        s.seller_city,
        s.seller_state

    from order_items oi
    left join products p on oi.product_id = p.product_id
    left join sellers  s on oi.seller_id  = s.seller_id

)

select * from final
