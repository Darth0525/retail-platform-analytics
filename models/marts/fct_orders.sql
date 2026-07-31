{{
    config(
        materialized='table',
        schema='marts'
    )
}}

-- fct_orders.sql
-- --------------
-- One row per order. Central fact table of the marts layer — joins order
-- details, payment summary, delivery location, and review score into a
-- single analytics-ready table.
--
-- Grain: one row per order_id
--
-- Key design decisions:
--   customer_id — uses customer_unique_id from stg_customers (not the per-order
--     customer_id) so it joins correctly to dim_customers.
--   delivery location — sourced from stg_customers for this specific order's
--     zip code, not from dim_customers (which holds last known address).
--     Reflects where this order was actually delivered.
--   reviews — LEFT JOIN on order_id AND is_duplicate_review = FALSE.
--     Orders with duplicate reviews (1.42%) get review_score = NULL since
--     their review's order mapping is ambiguous and unreliable.
--   payments — LEFT JOIN since 80 orders have incomplete payment sequences.
--
-- Derived columns:
--   is_delivered_on_time — NULL when order not yet delivered or timestamps missing
--   delivery_time_days   — NULL when order not yet delivered
--
-- Joins:
--   int_orders.customer_id         → stg_customers.customer_id
--   stg_customers.zip_code_prefix  → dim_geolocation.zip_code_prefix
--   int_orders.order_id            → int_order_payments.order_id
--   int_orders.order_id            → int_order_reviews.order_id (LEFT)

with orders as (

    select * from {{ ref('int_orders') }}

),

customers as (

    -- Only need customer_unique_id and zip for this join
    select
        customer_id,
        customer_unique_id,
        zip_code_prefix
    from {{ ref('stg_customers') }}

),

geolocation as (

    select * from {{ ref('dim_geolocation') }}

),

payments as (

    select
        order_id,
        primary_payment_type,
        installments,
        total_payment_value,
        has_payment_value_mismatch
    from {{ ref('int_order_payments') }}

),

reviews as (

    select
        order_id,
        score             as review_score,
        is_duplicate_review
    from {{ ref('int_order_reviews') }}

),

final as (

    select
        -- Primary key
        o.order_id,

        -- Foreign key to dim_customers
        c.customer_unique_id                                    as customer_id,

        -- Order status and timestamps
        o.status,
        o.purchased_at,
        o.approved_at,
        o.delivered_to_carrier_at,
        o.delivered_to_customer_at,
        o.estimated_delivery_date,

        -- Delivery quality flags from int_orders
        o.is_valid_delivery,

        -- On time: TRUE if delivered on or before estimated date
        -- NULL when order not yet delivered or timestamps missing
        case
            when o.delivered_to_customer_at is null
              or o.estimated_delivery_date  is null then null
            when o.delivered_to_customer_at
                    <= o.estimated_delivery_date    then true
            else false
        end                                                     as is_delivered_on_time,

        -- Days from purchase to delivery — NULL if not yet delivered
        datediff(
            day,
            o.purchased_at,
            o.delivered_to_customer_at
        )                                                       as delivery_time_days,

        -- Delivery location for this specific order
        -- (may differ from customer's last known address in dim_customers)
        c.zip_code_prefix                                       as delivery_zip_code_prefix,
        g.city                                                  as delivery_city,
        g.state                                                 as delivery_state,

        -- Payment summary from int_order_payments
        p.primary_payment_type,
        p.installments,
        p.total_payment_value,
        p.has_payment_value_mismatch,                          -- DQ flag: payment vs items total mismatch

        -- Review from int_order_reviews (NULL if customer did not submit a review)
        r.review_score,
        r.is_duplicate_review                                  -- DQ flag: review had ambiguous order mapping

    from orders o
    inner join customers  c on o.customer_id    = c.customer_id
    left join  geolocation g on c.zip_code_prefix = g.zip_code_prefix
    left join  payments    p on o.order_id        = p.order_id
    -- Only join reviews where order mapping is reliable — duplicate reviews
    -- have ambiguous order_id so they are excluded (review_score = NULL for those orders)
    left join  reviews     r on o.order_id        = r.order_id
                             and r.is_duplicate_review = false

)

select * from final
