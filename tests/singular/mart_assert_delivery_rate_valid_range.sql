-- mart_assert_delivery_rate_valid_range.sql
-- ------------------------------------------
-- Validates that on_time_delivery_rate is always between 0 and 1 (inclusive)
-- when not null. A rate outside this range indicates a calculation error in
-- the aggregation logic in mart_customer_summary or mart_seller_performance.

{{ config(severity='error') }}

SELECT 'mart_customer_summary' as model, customer_id as entity_id, on_time_delivery_rate
FROM {{ ref('mart_customer_summary') }}
WHERE on_time_delivery_rate IS NOT NULL
  AND (on_time_delivery_rate < 0 OR on_time_delivery_rate > 1)

UNION ALL

SELECT 'mart_seller_performance' as model, seller_id as entity_id, on_time_delivery_rate
FROM {{ ref('mart_seller_performance') }}
WHERE on_time_delivery_rate IS NOT NULL
  AND (on_time_delivery_rate < 0 OR on_time_delivery_rate > 1)
