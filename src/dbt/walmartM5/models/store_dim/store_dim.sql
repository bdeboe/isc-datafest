
WITH store_dim AS (
  SELECT DISTINCT
    STORE_ID
  FROM {{ source('walmart', 'walmart') }}
)

SELECT *
FROM store_dim
