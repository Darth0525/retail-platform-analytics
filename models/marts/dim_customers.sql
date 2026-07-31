{{
    config(
        materialized='table',
        schema='marts'
    )
}}

-- dim_customers.sql
-- -----------------
-- One row per real customer. Primary key is customer_unique_id from source,
-- renamed to customer_id at the marts layer for simplicity.
--
-- Why customer_unique_id and not customer_id from stg_customers:
--   Olist generates a new customer_id per order — one real customer who places
--   3 orders has 3 different customer_ids. customer_unique_id is the true
--   identity that stays consistent across all orders for the same person.
--   stg_customers has 99,441 rows; this model has 96,096 (one per real customer).
--
-- Location strategy — latest known zip:
--   250 customers (0.26%) have different zip codes across their orders,
--   indicating a real address change between purchases. Using MAX(zip) would
--   be arbitrary. Instead we join to stg_orders to find the most recent
--   purchased_at per customer and use that order's zip — "last known address."
--
-- City and state sourced from int_geolocation_by_zip, not stg_customers:
--   Raw customer city/state has spelling variations (e.g. 'sao paulo' vs
--   'São Paulo'). Geolocation-derived values are standardized via MODE()
--   across thousands of entries per zip, making them more reliable for
--   grouping and filtering in reports.
--
-- Joins:
--   stg_customers.customer_id  → stg_orders.customer_id (to get latest order date)
--   stg_customers.zip_code_prefix → int_geolocation_by_zip.zip_code_prefix

with customers as (

    select * from {{ ref('stg_customers') }}

),

orders as (

    -- Only need customer_id and purchased_at to determine most recent order
    select
        customer_id,
        purchased_at
    from {{ ref('stg_orders') }}

),

geolocation as (

    select * from {{ ref('dim_geolocation') }}

),

-- Get the zip code from the customer's most recent order
-- QUALIFY keeps only the latest row per customer_unique_id
latest_customer as (

    select
        c.customer_unique_id,
        c.zip_code_prefix
    from customers c
    inner join orders o on c.customer_id = o.customer_id

    -- Pick the row with the most recent purchase date per real customer
    qualify row_number() over (
        partition by c.customer_unique_id
        order by o.purchased_at desc
    ) = 1

),

final as (

    select
        -- Primary key — renamed from customer_unique_id for simplicity at marts layer
        l.customer_unique_id    as customer_id,

        -- Location as of most recent order — standardized via geolocation lookup
        l.zip_code_prefix,
        g.city,
        g.state

    from latest_customer l
    left join geolocation g on l.zip_code_prefix = g.zip_code_prefix

)

select * from final
