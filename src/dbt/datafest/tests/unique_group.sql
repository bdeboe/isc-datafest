{% test unique_group(model, columns) %}
select * from (
select 
{% for column in columns -%}{{ adapter.quote(column) }}{{ ',' if not loop.last }}{%- endfor -%},
count(*) cnt
from {{ model }}
group by {% for column in columns -%}{{ adapter.quote(column) }}{{ ',' if not loop.last }}{%- endfor -%}
) where cnt>1
{% endtest %}