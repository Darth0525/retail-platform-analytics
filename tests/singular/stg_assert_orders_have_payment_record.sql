-- stg_assert_orders_have_payment_record.sql
-- -------------------------------------------
-- Validates that every order in stg_orders has at least one matching row
-- in stg_order_payments. Every order must have a payment record.
--
-- Known issue: 1 order in source data has no payment record at all despite
-- having status = 'delivered'. The payment data was never captured by Olist's
-- system for this order. Surfaced when mart_customer_summary returned NULL
-- total_spend for one customer. Handled in mart_customer_summary via
-- COALESCE(total_payment_value, 0).
-- Severity set to warn so the pipeline is not blocked by known dirty data.

{{ config(severity='warn') }}

SELECT
    o.order_id,
    o.status
FROM {{ ref('stg_orders') }} o
LEFT JOIN {{ ref('stg_order_payments') }} p ON o.order_id = p.order_id
WHERE p.order_id IS NULL
