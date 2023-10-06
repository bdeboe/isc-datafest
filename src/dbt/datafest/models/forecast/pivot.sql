{% set field = var('pivot-field') %}

{% if execute %}
    {% set query %}
        SELECT DISTINCT {{ field }} FROM {{ source('files','walmart')}}
    {% endset %}
    {% set vals = run_query(query).columns[0].values() %}
{% else %}
    {% set vals = [] %}
{% endif %}



SELECT 
  CAST(DT AS TIMESTAMP) as sell_date, 
  
  {% for val in vals %}

    CASE WHEN {{ field }} = '{{ val }}' THEN UNITS_SOLD ELSE NULL END AS units_sold_{{val}}
    
    {% if not loop.last %},{% endif %}
  
  {% endfor %}
  
FROM {{ source('files', 'walmart') }}