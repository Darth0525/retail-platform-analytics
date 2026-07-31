-- mart_assert_total_spend_non_negative.sql
-- -----------------------------------------
-- Validates that total_spend is always >= 0 in mart_customer_summary.
-- A negative total spend would indicate a calculation error — payment
-- values in source data are always positive amounts in BRL.

{{ config(severity='error') }}

SELECT customer_id, total_spend
FROM {{ ref('mart_customer_summary') }}
WHERE total_spend < 0
