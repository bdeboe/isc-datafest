
WITH dept_dim AS (
  SELECT DISTINCT
    DEPT_ID
  FROM {{ source('walmart', 'walmart') }}
)

SELECT *
FROM dept_dim
