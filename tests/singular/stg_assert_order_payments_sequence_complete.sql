-- stg_assert_order_payments_sequence_complete.sql
-- -------------------------------------------------
-- Validates that payment_sequential values form a complete sequence
-- starting at 1 for every order (1, 2, 3... with no gaps or missing start).
--
-- Logic: if the sequence is complete, MAX(payment_sequential) equals COUNT(*).
-- This catches two failure modes:
--   1. Missing first row  — sequence starts at 2 or higher (e.g. 2, 3)
--   2. Gaps in sequence   — a middle row is missing (e.g. 1, 3, 4)
--
-- Known issue: 80 orders in source data have incomplete sequences.
-- All are missing their sequential = 1 row — the first payment record
-- simply does not exist in the Olist dataset for these orders.
-- Severity set to warn so the pipeline is not blocked by known dirty data.

{{ config(severity='warn') }}

SELECT
    order_id,
    COUNT(*)                 as payment_row_count,
    MIN(payment_sequential)  as min_sequential,
    MAX(payment_sequential)  as max_sequential
FROM {{ ref('stg_order_payments') }}
GROUP BY order_id
HAVING MAX(payment_sequential) != COUNT(*)
