{% macro iris__get_create_index_sql(relation, index_config) -%}
  {%- set comma_separated_columns = ", ".join(index_config.columns) -%}
  {%- set comma_separated_data = ", ".join(index_config.data if index_config.data else []) -%}
  {%- set index_name = index_config.name -%}

  create {% if index_config.unique -%}
    unique
  {% elif index_config.type%}{{ index_config.type}}{%- endif %} index
  "{{ index_name }}"
  on {{ relation }} ({{ comma_separated_columns }})
  {% if comma_separated_data %}
  with data ({{ comma_separated_data }})
  {% endif %}
{%- endmacro %}