{% macro generate_schema_name(custom_schema_name, node) -%}
    {{ target.schema ~ '_' ~ dbt_utils.slugify(var('target')) ~ '_m' ~ var('target-horizon-months') }}
{%- endmacro %}