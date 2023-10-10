
WITH dept_dim AS (
  SELECT DISTINCT
    DEPT_ID
  FROM {{ source('files', 'walmart') }}
)

SELECT *
FROM dept_dim
