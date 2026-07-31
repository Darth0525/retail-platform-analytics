{{
    config(
        materialized='view',
        schema='staging'
    )
}}

-- stg_order_reviews.sql
-- ---------------------
-- Staging model for the raw order_reviews table. One row per review.
-- Reviews are submitted by customers after delivery. Most customers only
-- provide a score — comment fields are commonly null.
--
-- Joins:
--   stg_order_reviews.order_id → stg_orders.order_id
--
-- Primary key: review_id
--
-- Changes from raw:
--   - Redundant REVIEW_ prefix dropped from score, comment_title, comment_message
--   - REVIEW_CREATION_DATE renamed to created_at and cast from TEXT to TIMESTAMP
--   - REVIEW_ANSWER_TIMESTAMP renamed to answered_at and cast from TEXT to TIMESTAMP

with source as (

    select * from {{ source('olist', 'order_reviews') }}

),

renamed as (

    select
        -- Primary key
        review_id,

        -- Foreign key
        order_id,   -- joins to stg_orders

        -- Review content
        review_score           as score,           -- 1 (worst) to 5 (best)
        review_comment_title   as comment_title,   -- optional, commonly null
        review_comment_message as comment_message, -- optional, commonly null

        -- Timestamps — cast from TEXT to TIMESTAMP
        try_to_timestamp(review_creation_date)    as created_at,   -- when survey was sent
        try_to_timestamp(review_answer_timestamp) as answered_at   -- when customer submitted

    from source

)

select * from renamed
