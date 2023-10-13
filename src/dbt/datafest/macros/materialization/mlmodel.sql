{% materialization mlmodel, adapter='iris' %}
{%- set target_relation = this.incorporate(type='table') %}
{%- set model_name = this.schema ~ '_' ~ this.identifier %}
{%- set model_relation = this.incorporate(schema=None, identifier=model_name, type='external') %}
{% do log('create ml model ' ~ model_name, info=true) %}

{% set existing = adapter.get_relation(identifier=target_relation.identifier, schema=target_relation.schema, database=target_relation.database) %}
{% if existing %}
  {% do adapter.drop_relation(existing) %}
{% endif %}

{% call statement('create table') -%}
create view {{ target_relation }}
as {{ compiled_code }};
{% endcall %}

{% call statement('drop model') -%}
drop model if exists {{ model_name }}
{%- endcall %}

{% call statement('create model') -%}
create model {{ model_name }} predicting ({{ adapter.quote(config.get('predicting')) }})
{%- if config.get('with_dataset') -%}
{% set with = code_to_col(dbt_utils.get_column_values(ref(config.get('with_dataset')), 'code')) %}
{% set columns = adapter.get_columns_in_relation(target_relation) %}
with (
    {% for col in columns if col.name in with %}
    {{ col.name }} {{ modules.re.sub('character varying', 'varchar', col.data_type) }}
    {%- if not loop.last %},{{ '\n' }}{% endif -%}
    {% endfor %}
) {% endif %}
from {{ target_relation }}
{%- endcall %}

{% call statement('main') -%}
train model {{ model_name }}
{%- endcall %}

{{ adapter.commit() }}

{{ return({'relations': [target_relation, model_relation]}) }}
{% endmaterialization %}