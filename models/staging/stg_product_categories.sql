{{
    config(
        materialized='view',
        schema='staging'
    )
}}

-- stg_product_categories.sql
-- --------------------------
-- Staging model for the product category name translation table.
-- 71 rows — one per product category, translating Portuguese names to English.
--
-- Joins:
--   stg_products.category_name_portuguese → stg_product_categories.category_name_portuguese
--
-- Changes from raw:
--   - PRODUCT_CATEGORY_NAME renamed to category_name_portuguese for clarity
--   - PRODUCT_CATEGORY_NAME_ENGLISH renamed to category_name (English is our standard output)
--   - No type casting needed

with source as (

    select * from {{ source('olist', 'product_category_name_translation') }}

),

renamed as (

    select
        -- Portuguese category name — joins to stg_products.category_name_portuguese
        product_category_name         as category_name_portuguese,

        -- English translation — use this as the display name in all downstream models
        product_category_name_english as category_name

    from source

)

select * from renamed
