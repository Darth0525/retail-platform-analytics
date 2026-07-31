{{
    config(
        materialized='view',
        schema='intermediate'
    )
}}

-- int_order_reviews.sql
-- ---------------------
-- Deduplicates stg_order_reviews on review_id.
--
-- Problem: source data contains 789 review_ids that appear on more than one
-- order (1.42% of orders affected). This is a data quality issue in Olist's
-- review ID generation — not customers submitting duplicate reviews.
-- Scores and timestamps are identical on duplicate rows, so we cannot
-- determine which order_id the review truly belongs to.
--
-- Deduplication strategy (two steps):
--   Step 1 — PARTITION BY review_id: 789 review_ids appear on multiple orders.
--     Picks one row per review_id (alphabetical order_id as tiebreaker).
--   Step 2 — PARTITION BY order_id: 91 orders have two distinct review_ids
--     both pointing to the same order (separate Olist data quality issue).
--     Keeps the review with the highest score (score desc, review_id as tiebreaker).
--
-- is_duplicate_review flag:
--   TRUE  — this review_id appeared on more than one order in staging
--   FALSE — review_id was unique, no ambiguity
--   Use this flag to exclude or caveat order-level review joins downstream.

with source as (

    select * from {{ ref('stg_order_reviews') }}

),

-- Count how many times each review_id appears — used to set the duplicate flag
review_counts as (

    select
        review_id,
        count(*) as review_id_count
    from source
    group by review_id

),

flagged as (

    select
        s.review_id,
        s.order_id,
        s.score,
        s.comment_title,
        s.comment_message,
        s.created_at,
        s.answered_at,

        -- TRUE when this review_id appeared on more than one order in source data
        -- Order-level joins on these rows have ambiguous review association
        case
            when c.review_id_count > 1 then true
            else false
        end as is_duplicate_review

    from source s
    inner join review_counts c on s.review_id = c.review_id

),

-- Step 1: deduplicate on review_id — handles 789 review_ids appearing on multiple orders
deduped_by_review as (

    select *
    from flagged

    -- Keep one row per review_id — order_id used as arbitrary but deterministic tiebreaker
    qualify row_number() over (partition by review_id order by order_id) = 1

),

-- Step 2: deduplicate on order_id — handles 91 orders that have two distinct review_ids
-- both pointing to the same order (separate Olist data quality issue)
-- Keep the review with the highest score as a conservative choice
deduped as (

    select *
    from deduped_by_review

    qualify row_number() over (partition by order_id order by score desc, review_id) = 1

)

select * from deduped
