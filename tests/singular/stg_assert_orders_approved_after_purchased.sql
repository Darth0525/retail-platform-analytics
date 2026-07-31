-- assert_orders_approved_after_purchased.sql
-- -------------------------------------------
-- Validates that order approval always happens after the purchase timestamp.
-- An order cannot be approved before it was placed.
--
-- Test passes when this query returns 0 rows.

SELECT
    order_id,
    purchased_at,
    approved_at
FROM {{ ref('stg_orders') }}
WHERE
    -- Only check rows where approval timestamp exists
    approved_at IS NOT NULL
    -- Flag any order approved before it was purchased
    AND approved_at < purchased_at
