{% set cols = dbt_utils.get_filtered_columns_in_relation(ref('pivot'), except=['sell_date']) %}

SELECT 
    sell_Date,

    {% for col in cols %}
        SUM( {{col}} ) AS {{col}}
        {% if not loop.last %},{% endif %}
    {% endfor %}
    
FROM  {{ ref('pivot') }}
GROUP BY sell_date