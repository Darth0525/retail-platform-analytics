-- stg_assert_orders_delivery_date_sequence.sql
-- ---------------------------------------------
-- Validates that the delivery date sequence is logically consistent:
-- delivered_to_customer_at must be AFTER delivered_to_carrier_at.
--
-- A carrier must receive the package before the customer can receive it.
-- Any row returned by this query is a data quality failure.
-- Test passes when this query returns 0 rows.
--
-- Known issue: 23 orders in the source data violate this rule — timestamps
-- appear to have been recorded incorrectly by Olist. Severity set to warn
-- so the pipeline is not blocked by known dirty source data.

{{ config(severity='warn') }}

SELECT
    order_id,
    delivered_to_carrier_at,
    delivered_to_customer_at
FROM {{ ref('stg_orders') }}
WHERE
    -- Only check rows where both timestamps are present
    delivered_to_carrier_at   IS NOT NULL
    AND delivered_to_customer_at IS NOT NULL
    -- Flag any order where customer received before carrier did
    AND delivered_to_customer_at < delivered_to_carrier_at
