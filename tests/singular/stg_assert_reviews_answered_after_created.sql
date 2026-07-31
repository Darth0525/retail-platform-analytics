-- assert_reviews_answered_after_created.sql
-- ------------------------------------------
-- Validates that review submission (answered_at) always happens after
-- the review survey was sent (created_at).
-- A customer cannot submit a review before they receive the survey.
--
-- Test passes when this query returns 0 rows.

SELECT
    review_id,
    created_at,
    answered_at
FROM {{ ref('stg_order_reviews') }}
WHERE
    -- Both timestamps should always be present, but guard against nulls
    created_at  IS NOT NULL
    AND answered_at IS NOT NULL
    -- Flag any review answered before the survey was sent
    AND answered_at < created_at
