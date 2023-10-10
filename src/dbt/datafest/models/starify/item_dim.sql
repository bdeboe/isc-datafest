
WITH item_dim AS (
  SELECT DISTINCT
    ITEM_ID
  FROM {{ source('files', 'walmart') }}
)

SELECT *
FROM item_dim
