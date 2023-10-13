{{ config(materialized='nonnull') }}
SELECT id from {{ ref('summary') }}