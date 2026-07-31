{{
    config(
        materialized='view',
        schema='staging'
    )
}}

-- stg_products.sql
-- ----------------
-- Staging model for the raw products table. One row per product.
-- Products are the items listed by sellers on the Olist marketplace.
-- Some products have incomplete data — category and dimension columns can be null.
--
-- Joins:
--   stg_order_items.product_id → stg_products.product_id
--   stg_products.category_name_portuguese → stg_product_categories.category_name_portuguese
--
-- Changes from raw:
--   - Redundant PRODUCT_ prefix dropped from most columns
--   - Unit suffixes (_g, _cm) preserved — important context for numeric columns
--   - Typos fixed: PRODUCT_NAME_LENGHT → product_name_length
--                  PRODUCT_DESCRIPTION_LENGHT → product_description_length
--   - No type casting needed — numeric columns already loaded as FLOAT

with source as (

    select * from {{ source('olist', 'products') }}

),

renamed as (

    select
        -- Primary key
        product_id,

        -- Category — Portuguese name joins to stg_product_categories for English translation.
        -- Can be null for products with incomplete data.
        product_category_name         as category_name_portuguese,

        -- Text metrics — typos corrected from source (LENGHT → length)
        product_name_lenght           as product_name_length,
        product_description_lenght    as product_description_length,
        product_photos_qty            as photos_qty,

        -- Physical dimensions — unit suffixes (_g, _cm) kept to avoid ambiguity
        -- in downstream models. Can be null for products with incomplete data.
        product_weight_g              as weight_g,
        product_length_cm             as length_cm,
        product_height_cm             as height_cm,
        product_width_cm              as width_cm

    from source

)

select * from renamed
