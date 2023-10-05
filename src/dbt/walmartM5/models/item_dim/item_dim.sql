
WITH item_dim AS (
  SELECT DISTINCT
    ITEM_ID
  FROM {{ source('walmart', 'walmart') }}
)

SELECT *
FROM item_dim
