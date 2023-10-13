{% materialization nonnull, default %}

{%- set target_relation = this.incorporate(type='table') %}

{% set existing = adapter.get_relation(identifier=target_relation.identifier, schema=target_relation.schema, database=target_relation.database) %}
{% if existing %}
  {% do adapter.truncate_relation(existing) %}
  {% do adapter.drop_relation(existing) %}
{% endif %}

{% call statement('get_summary_location', fetch_result=True) %}
select top 1 DataLocation from "%Dictionary"."StorageDefinition" where parent=(
    select classname from information_schema.tables where table_name = 'summary' and table_schema= '{{ this.schema }}'
);
{% endcall %}

{%- set summary_location = load_result('get_summary_location').table | map(attribute='DataLocation') | list | first %}

{% call statement('prepare_table', fetch_result=False) %}
create table {{ target_relation }} (id INTEGER)
with %CLASSPARAMETER SUMMARYLOCATION = '{{ summary_location }}'
{% endcall %}

{% call statement('add key', fetch_result=False) %}
alter table {{ target_relation }} add column key VARCHAR(50)
COMPUTECODE { set {*} = $ListGet({{ summary_location }}({id})) }
{% endcall %}

{% call statement('add counter', fetch_result=False) %}
alter table {{ target_relation }} add column cnt INTEGER
COMPUTECODE { set cnt=0,data=$Get({{ summary_location }}({id})),ptr=0 while $listnext(data,ptr,val) { set cnt = cnt + (val'="" ) } set {*} = cnt }
{% endcall %}

{% call statement('index counter', fetch_result=False) %}
create index counteridx on table {{ target_relation }} (cnt) with data (key)
{% endcall %}

{% call statement('main') -%}
insert into {{ target_relation }}
{{ compiled_code }}
{%- endcall %}

{{ adapter.commit() }}

{{ return({'relations': [target_relation]}) }}

{% endmaterialization %}