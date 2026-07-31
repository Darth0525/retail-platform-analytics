-- assert_order_items_positive_values.sql
-- ----------------------------------------
-- Validates that price and freight_value are always positive numbers.
-- A zero or negative price indicates corrupt or erroneous source data.
-- Freight can legitimately be 0 (free shipping) but never negative.
--
-- Test passes when this query returns 0 rows.

SELECT
    order_id,
    order_item_id,
    price,
    freight_value
FROM {{ ref('stg_order_items') }}
WHERE
    price         <= 0   -- price must always be greater than zero
    OR freight_value < 0 -- freight can be 0 (free shipping) but never negative
