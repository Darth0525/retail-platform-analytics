{{
    config(
        materialized='table',
        schema='marts'
    )
}}

-- dim_products.sql
-- ----------------
-- One row per product listed on the Olist marketplace.
-- stg_products is already unique on product_id — no deduplication needed.
--
-- Adds English category name by joining to stg_product_categories.
-- Some products have null category_name_portuguese in source data —
-- those will have null category_name and category_name_portuguese in this model.
--
-- Physical dimensions (weight, length, height, width) are retained as they
-- can be used to analyze the relationship between product size and freight cost.
--
-- Joins:
--   stg_products.category_name_portuguese → stg_product_categories.category_name_portuguese

with products as (

    select * from {{ ref('stg_products') }}

),

categories as (

    select * from {{ ref('stg_product_categories') }}

),

final as (

    select
        -- Primary key
        p.product_id,

        -- Category — Portuguese from source, English from lookup table
        p.category_name_portuguese,
        c.category_name,                    -- English translation, null if category is null in source

        -- Product listing attributes
        p.product_name_length,              -- can be null for products with incomplete data
        p.product_description_length,       -- can be null for products with incomplete data
        p.photos_qty,                       -- can be null for products with incomplete data

        -- Physical dimensions — used to analyze freight cost relationships
        p.weight_g,                         -- can be null for products with incomplete data
        p.length_cm,                        -- can be null for products with incomplete data
        p.height_cm,                        -- can be null for products with incomplete data
        p.width_cm                          -- can be null for products with incomplete data

    from products p
    left join categories c
        on p.category_name_portuguese = c.category_name_portuguese

)

select * from final
