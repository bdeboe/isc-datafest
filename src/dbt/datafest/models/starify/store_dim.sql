
WITH store_dim AS (
  SELECT DISTINCT
    STORE_ID
  FROM {{ source('files', 'walmart') }}
)

SELECT *
FROM store_dim
