
WITH cat_dim AS (
  SELECT DISTINCT
    CAT_ID
  FROM {{ source('walmart', 'walmart') }}
)

SELECT *
FROM cat_dim
