-- stg_assert_order_reviews_one_review_per_order.sql
-- ---------------------------------------------------
-- Validates that each order_id has at most one review in the source data.
-- A review is triggered by a specific order delivery — one order should
-- never receive more than one review.
--
-- Known issue: 547 orders in source data have more than one review_id mapped
-- to the same order_id. Scores are identical on duplicate rows, indicating
-- a review ID generation bug in Olist's system.
-- This is a separate issue from the 789 duplicate review_ids (same review_id
-- on multiple orders) captured in stg_assert_order_reviews_unique_review_per_order.
-- After the first deduplication step in int_order_reviews (by review_id), 91
-- orders still have multiple reviews — deduplication on order_id handles those.
-- Severity set to warn so the pipeline is not blocked by known dirty data.

{{ config(severity='warn') }}

SELECT
    order_id,
    COUNT(*) as review_count
FROM {{ ref('stg_order_reviews') }}
GROUP BY order_id
HAVING COUNT(*) > 1
