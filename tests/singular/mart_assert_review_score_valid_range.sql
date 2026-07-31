-- mart_assert_review_score_valid_range.sql
-- -----------------------------------------
-- Validates that avg_review_score is always between 1 and 5 (inclusive)
-- when not null. Scores outside this range indicate a calculation error —
-- source scores are integers 1-5 so their average must fall within this range.

{{ config(severity='error') }}

SELECT 'mart_customer_summary' as model, customer_id as entity_id, avg_review_score
FROM {{ ref('mart_customer_summary') }}
WHERE avg_review_score IS NOT NULL
  AND (avg_review_score < 1 OR avg_review_score > 5)

UNION ALL

SELECT 'mart_seller_performance' as model, seller_id as entity_id, avg_review_score
FROM {{ ref('mart_seller_performance') }}
WHERE avg_review_score IS NOT NULL
  AND (avg_review_score < 1 OR avg_review_score > 5)
