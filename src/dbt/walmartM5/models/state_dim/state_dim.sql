
WITH state_dim AS (
  SELECT DISTINCT
    STATE_ID
  FROM {{ source('walmart', 'walmart') }}
)

SELECT *
FROM state_dim
