
WITH state_dim AS (
  SELECT DISTINCT
    STATE_ID
  FROM {{ source('files', 'walmart') }}
)

SELECT *
FROM state_dim
