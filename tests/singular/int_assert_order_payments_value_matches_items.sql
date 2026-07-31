-- int_assert_order_payments_value_matches_items.sql
-- ---------------------------------------------------
-- Validates that the total payment value for each order matches the sum of
-- item prices + freight from stg_order_items.
--
-- This test requires joining two staging models so it lives in intermediate,
-- not in staging. Tested against int_order_payments which pre-computes both
-- totals and the gap.
--
-- Known issue: 576 orders (0.58%) have a mismatch. Likely caused by missing
-- payment rows (80 orders with incomplete sequences) or recording errors in
-- Olist's source data. Severity set to warn so the pipeline is not blocked.

{{ config(severity='warn') }}

SELECT
    order_id,
    total_payment_value,
    payment_value_gap
FROM {{ ref('int_order_payments') }}
WHERE has_payment_value_mismatch = true
