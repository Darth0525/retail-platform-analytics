{{
    config(
        materialized='view',
        schema='staging'
    )
}}

-- stg_order_payments.sql
-- ----------------------
-- Staging model for the raw order_payments table. One row per payment method per order.
-- An order can have multiple rows if the customer split payment across methods
-- (e.g. credit card + voucher). Boleto is a Brazilian bank slip payment method.
--
-- Joins:
--   stg_order_payments.order_id → stg_orders.order_id
--
-- Primary key: composite of order_id + payment_sequential
--
-- Changes from raw:
--   - No renaming needed — columns are already clean and descriptive
--   - No type casting needed — numeric columns already correct types

with source as (

    select * from {{ source('olist', 'order_payments') }}

),

renamed as (

    select
        -- Composite primary key: one order can have multiple payment methods
        order_id,
        payment_sequential,    -- counter (1, 2, 3...) numbering each payment method per order

        -- Payment details
        payment_type,          -- credit_card, boleto, voucher, debit_card
        payment_installments,  -- number of installments. 1 = paid in full
        payment_value          -- value of this payment in BRL

    from source

)

select * from renamed
