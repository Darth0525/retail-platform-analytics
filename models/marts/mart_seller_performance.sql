{{
    config(
        materialized='table',
        schema='marts'
    )
}}

-- mart_seller_performance.sql
-- ---------------------------
-- One row per seller. Pre-aggregated summary of seller sales, delivery,
-- and customer satisfaction performance across the full dataset period (2016-2018).
--
-- Business questions answered:
--   - Which sellers generate the most revenue?
--   - Which sellers have the best/worst delivery times?
--   - Which sellers have the highest customer satisfaction scores?
--   - Which sellers deliver on time most consistently?
--   - How diverse is each seller's product category range?
--
-- Note on delivery metrics:
--   avg_delivery_time_days and on_time_delivery_rate are calculated from
--   fct_orders joined on order_id. Only orders with valid delivery data
--   (is_valid_delivery IS NOT NULL) are included in these calculations.
--
-- Note on time-based columns:
--   For a production pipeline, FY/quarterly/monthly breakdowns would be
--   derived by querying fct_order_items directly with DATE_TRUNC grouping.
--
-- Joins:
--   fct_order_items.seller_id → dim_sellers.seller_id
--   fct_order_items.order_id  → fct_orders.order_id

with order_items as (

    select * from {{ ref('fct_order_items') }}

),

orders as (

    -- Only need delivery and review metrics from fct_orders
    select
        order_id,
        delivery_time_days,
        review_score,
        is_valid_delivery,
        is_delivered_on_time
    from {{ ref('fct_orders') }}

),

sellers as (

    select * from {{ ref('dim_sellers') }}

),

-- Join items to order-level metrics
items_with_order_metrics as (

    select
        oi.seller_id,
        oi.order_id,
        oi.order_item_id,
        oi.price,
        oi.freight_value,
        oi.category_name,
        o.delivery_time_days,
        o.review_score,
        o.is_valid_delivery,
        o.is_delivered_on_time
    from order_items oi
    left join orders o on oi.order_id = o.order_id

),

final as (

    select
        -- Primary key
        i.seller_id,

        -- Seller location from dim_sellers
        s.city,
        s.state,

        -- Sales volume
        count(distinct i.order_id)               as total_orders,
        count(i.order_item_id)                   as total_items_sold,

        -- Revenue
        round(sum(i.price), 2)                   as total_revenue,
        round(avg(i.price), 2)                   as avg_item_price,
        round(sum(i.freight_value), 2)           as total_freight_charged,

        -- Delivery performance — only among orders with valid delivery data
        round(avg(i.delivery_time_days), 1)      as avg_delivery_time_days,
        round(
            sum(case when i.is_delivered_on_time = true  then 1 else 0 end)
            / nullif(
                sum(case when i.is_valid_delivery is not null then 1 else 0 end)
              , 0)
        , 2)                                     as on_time_delivery_rate,

        -- Customer satisfaction — excludes NULLs (no review or duplicate review)
        round(avg(i.review_score), 2)            as avg_review_score,

        -- Product diversity
        count(distinct i.category_name)          as distinct_categories

    from items_with_order_metrics i
    left join sellers s on i.seller_id = s.seller_id
    group by i.seller_id, s.city, s.state

)

select * from final
