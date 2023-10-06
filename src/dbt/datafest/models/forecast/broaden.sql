

SELECT 
  CAST(DT AS TIMESTAMP) as sell_date, 

  CASE WHEN CAT_ID = 'FOODS' THEN UNITS_SOLD ELSE NULL END AS units_sold_foods, 
  CASE WHEN CAT_ID = 'HOUSEHOLD' THEN UNITS_SOLD ELSE NULL END AS units_sold_household
  
FROM {{ source('files', 'walmart') }}