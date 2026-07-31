-- mart_assert_total_orders_positive.sql
-- ---------------------------------------
-- Validates that total_orders is always greater than 0 in both mart tables.
-- Every customer and seller in the mart must have placed or fulfilled
-- at least one order — a zero or negative value indicates an aggregation error.

{{ config(severity='error') }}

SELECT 'mart_customer_summary' as model, customer_id as entity_id, total_orders
FROM {{ ref('mart_customer_summary') }}
WHERE total_orders <= 0

UNION ALL

SELECT 'mart_seller_performance' as model, seller_id as entity_id, total_orders
FROM {{ ref('mart_seller_performance') }}
WHERE total_orders <= 0
