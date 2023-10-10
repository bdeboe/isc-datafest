
WITH cat_dim AS (
  SELECT DISTINCT
    CAT_ID
  FROM {{ source('files', 'walmart') }}
)

SELECT *
FROM cat_dim
