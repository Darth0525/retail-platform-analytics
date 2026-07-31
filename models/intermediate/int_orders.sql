{{
    config(
        materialized='view',
        schema='intermediate'
    )
}}

-- int_orders.sql
-- --------------
-- Extends stg_orders with a delivery sequence validity flag.
-- Flags the 23 known orders where delivered_to_customer_at < delivered_to_carrier_at
-- (carrier must receive the package before the customer can).
--
-- is_valid_delivery:
--   TRUE  — both timestamps present and sequence is correct
--   FALSE — both timestamps present but sequence is wrong (dirty source data)
--   NULL  — one or both timestamps missing (order not yet delivered)
--
-- All other columns passed through unchanged from stg_orders.

with source as (

    select * from {{ ref('stg_orders') }}

),

flagged as (

    select
        -- All columns from stg_orders passed through unchanged
        order_id,
        customer_id,
        status,
        purchased_at,
        approved_at,
        delivered_to_carrier_at,
        delivered_to_customer_at,
        estimated_delivery_date,

        -- Delivery sequence validity flag
        -- NULL when either timestamp is missing (order not yet delivered)
        -- FALSE for the 23 known dirty rows where customer received before carrier
        -- >= used (not >) because same-day delivery is valid
        case
            when delivered_to_carrier_at   is null
              or delivered_to_customer_at  is null then null
            when delivered_to_customer_at >= delivered_to_carrier_at then true
            else false
        end as is_valid_delivery

    from source

)

select * from flagged
