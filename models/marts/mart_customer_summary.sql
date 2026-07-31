{{
    config(
        materialized='table',
        schema='marts'
    )
}}

-- mart_customer_summary.sql
-- -------------------------
-- One row per real customer. Pre-aggregated summary of customer purchase
-- behavior across the full dataset period (2016-2018).
--
-- Business questions answered:
--   - Who are our most valuable customers by total spend?
--   - What is the repeat purchase rate?
--   - How satisfied are customers on average?
--   - What share of orders are delivered on time per customer?
--
-- Note on time-based columns:
--   first_order_at and last_order_at reflect activity within the dataset period.
--   For a production pipeline, additional columns would be added:
--     total_orders_last_12m, total_spend_last_12m,
--     has_order_in_last_quarter, has_order_in_last_year
--   calculated relative to current date.
--
-- Note on on_time_delivery_rate:
--   Only counts orders where delivery timestamps are present and valid
--   (is_valid_delivery IS NOT NULL). Excludes undelivered and dirty rows.
--
-- Joins:
--   fct_orders.customer_id → dim_customers.customer_id

with orders as (

    select * from {{ ref('fct_orders') }}

),

final as (

    select
        -- Primary key
        customer_id,

        -- Order volume
        count(order_id)                                      as total_orders,

        -- Revenue — COALESCE handles 1 known order with no payment record in source
        round(sum(coalesce(total_payment_value, 0)), 2)      as total_spend,
        round(avg(coalesce(total_payment_value, 0)), 2)      as avg_order_value,

        -- Activity window within dataset period
        min(purchased_at)                                    as first_order_at,
        max(purchased_at)                                    as last_order_at,

        -- Customer satisfaction — excludes NULLs (orders with no review or duplicate review)
        round(avg(review_score), 2)                          as avg_review_score,

        -- On time delivery rate — only among orders with valid delivery data
        round(
            sum(case when is_delivered_on_time = true  then 1 else 0 end)
            / nullif(
                sum(case when is_valid_delivery is not null then 1 else 0 end)
              , 0)
        , 2)                                                 as on_time_delivery_rate,

        -- Repeat customer flag
        count(order_id) > 1                                  as is_repeat_customer

    from orders
    group by customer_id

)

select * from final
