SELECT 
    sell_date, 
    SUM(units_sold_foods) AS units_sold_foods, 
    SUM(units_sold_household) AS units_sold_household 
FROM  {{ ref('broaden') }}
GROUP BY sell_date