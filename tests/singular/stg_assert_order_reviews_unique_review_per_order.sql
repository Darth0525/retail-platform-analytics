-- stg_assert_order_reviews_unique_review_per_order.sql
-- ------------------------------------------------------
-- Validates that each review_id maps to exactly one order_id.
-- A review is triggered by a specific order delivery — it should
-- never appear on more than one order.
--
-- Known issue: 789 review_ids in source data appear on more than one order
-- (1,412 orders affected — 1.42% of all orders). Scores and timestamps are
-- identical on duplicate rows, indicating a review ID generation bug in
-- Olist's system rather than customers submitting the same review twice.
-- The true primary key is the composite of review_id + order_id.
-- Deduplication is handled in int_order_reviews.
-- Severity set to warn so the pipeline is not blocked by known dirty data.

{{ config(severity='warn') }}

SELECT
    review_id,
    COUNT(DISTINCT order_id) as order_count
FROM {{ ref('stg_order_reviews') }}
GROUP BY review_id
HAVING COUNT(DISTINCT order_id) > 1
