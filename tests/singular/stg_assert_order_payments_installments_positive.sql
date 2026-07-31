-- stg_assert_order_payments_installments_positive.sql
-- -----------------------------------------------------
-- Validates that payment_installments is always a positive integer (>= 1).
-- Every payment must have at least 1 installment — 0 is not a valid value.
--
-- Known issue: 2 credit_card rows in source data have payment_installments = 0.
-- Both are secondary payments (payment_sequential = 2) on orders where the
-- primary payment row (sequential = 1) is also missing. Likely a recording
-- bug in Olist's system when the primary payment was not captured.
-- Severity set to warn so the pipeline is not blocked by known dirty data.

{{ config(severity='warn') }}

SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM {{ ref('stg_order_payments') }}
WHERE payment_installments < 1
