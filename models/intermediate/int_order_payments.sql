{{
    config(
        materialized='view',
        schema='intermediate'
    )
}}

-- int_order_payments.sql
-- ----------------------
-- Aggregates stg_order_payments from one row per payment method
-- to one row per order. Joins to stg_order_items to validate payment totals.
--
-- Data quality issues found in source data and handled here:
--
--   1. not_defined payment type (3 rows, 3 orders):
--      Olist did not record the payment method. Surfaced via has_not_defined_payment flag.
--
--   2. Incomplete payment sequences (80 orders):
--      MAX(payment_sequential) != COUNT(*) — either the sequential = 1 row is missing
--      or there are gaps mid-sequence (e.g. 1, 3, 4). Means total_payment_value and
--      payment_method_count are understated for these orders. Surfaced via
--      has_incomplete_payment_sequence flag.
--
--   3. payment_installments = 0 (2 credit_card rows):
--      Both are sequential = 2 rows on orders missing their primary payment.
--      Treated as 1 (paid in full) via GREATEST(..., 1).
--
--   4. Payment value mismatch (576 orders, 0.58%):
--      Sum of payment values does not match sum of item prices + freight from
--      stg_order_items. Could be caused by missing payment rows (issue 2 above)
--      or recording errors in source data. Surfaced via has_payment_value_mismatch
--      and payment_value_gap columns.
--
-- primary_payment_type definition:
--      Uses MAX_BY(payment_type, payment_value) — the method with the highest
--      payment value. More reliable than payment_sequential = 1 since 80 orders
--      are missing that row. Ties broken arbitrarily by Snowflake.

with payments as (

    select * from {{ ref('stg_order_payments') }}

),

-- Sum item price + freight per order — used to validate payment totals
order_items_total as (

    select
        order_id,
        round(sum(price + freight_value), 2) as items_total
    from {{ ref('stg_order_items') }}
    group by order_id

),

-- Aggregate all payment rows to one row per order
aggregated as (

    select
        order_id,

        -- Payment type with the highest payment value for this order
        -- More reliable than sequential = 1 since 80 orders are missing that row
        max_by(payment_type, payment_value)      as primary_payment_type,

        -- All payment types used — useful for orders with split payments
        array_agg(payment_type)                  as payment_types,

        -- Max installments across all rows; GREATEST handles the 2 dirty rows with value 0
        greatest(max(payment_installments), 1)   as installments,

        -- Total amount paid across all methods
        round(sum(payment_value), 2)             as total_payment_value,

        -- How many distinct payment methods were used
        count(distinct payment_type)             as payment_method_count,

        -- Flag: any row has not_defined payment type
        max(case when payment_type = 'not_defined' then 1 else 0 end) = 1
                                                 as has_not_defined_payment,

        -- Flag: sequence is incomplete (missing row or gap mid-sequence)
        -- MAX(sequential) should equal COUNT(*) for a complete 1,2,3... sequence
        max(payment_sequential) != count(*)      as has_incomplete_payment_sequence

    from payments
    group by order_id

),

-- Join items total to detect and measure payment value mismatches
final as (

    select
        a.order_id,
        a.primary_payment_type,
        a.payment_types,
        a.installments,
        a.total_payment_value,
        a.payment_method_count,
        a.has_not_defined_payment,
        a.has_incomplete_payment_sequence,

        -- Flag: payment total does not match item prices + freight total
        -- NULL when order not found in stg_order_items (defensive, should not occur)
        case
            when i.items_total is null                             then null
            when a.total_payment_value != i.items_total           then true
            else false
        end                                                        as has_payment_value_mismatch,

        -- Magnitude of mismatch in Brazilian Reais (BRL)
        -- Positive = customer underpaid vs item total
        -- Negative = customer overpaid vs item total
        -- NULL when items total not available
        case
            when i.items_total is null then null
            else round(i.items_total - a.total_payment_value, 2)
        end                                                        as payment_value_gap

    from aggregated a
    left join order_items_total i on a.order_id = i.order_id

)

select * from final
