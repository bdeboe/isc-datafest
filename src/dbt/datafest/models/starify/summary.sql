-- depends_on: {{ ref('synthea-lc-dataset-codes') }}
-- depends_on: {{ ref('synthea-stroke-dataset-codes') }}

{{ 
    config(
        materialized='table',
        indexes=[
            {'name': 'KeyIdx', 'columns': ['Key'], 'unique': True},
            {'name': 'TargetIdx', 'columns': ['target']},
        ]
    ) 
}}
{% set patients = ref('by_patient') %}
{% set tables = ['by_allergy', 'by_condition', 'by_procedure', 'by_encounter', 'by_observation'] %}
{% set except = target_columns() %}
{% do except.append('Key') %}
{% if execute %}
{% set all = run_query('select code from ' ~ target_codes_dataset()).columns[0].values() %}
{% else %}
{% set all = [] %}
{% endif %}
{# {% set present = target_columns() %} #}
{% set present = [] %}

select 
    P.Key,
    -- target-codes
    case when exists (select 1 from {{ ref('target_patients' )}} TargetPatients where TargetPatients.Subjectreference = P.Key) then 1 else 0 end target,
    -- by_patient
    {% set cols = dbt_utils.get_filtered_columns_in_relation(patients, except=['Key', 'TargetStartDate', 'TargetEndDate']) %}
    {% for col in cols %}{%- do present.append(col) -%}{{ adapter.quote(col) }} as {{ adapter.quote(modules.re.sub('[ -]+', '_', col)) }},{{ '\n' }}{% endfor %}
    {% for table in tables %}
        -- {{ table }}
        {% set cols = dbt_utils.get_filtered_columns_in_relation(ref(table), except=except) %}
        {% for col in cols %}
            {%- do present.append(col) -%}{{ adapter.quote(col) }} as {{ adapter.quote(modules.re.sub('[ -]+', '_', col)) }}{% if not loop.last %},{{ '\n' }}{% endif -%}
        {% endfor %}
        {% if not loop.last %},{% endif %}
    {% endfor -%}

    -- missing codes
{% for col in all %}{% if col not in present -%}
    , NULL as {{ adapter.quote(modules.re.sub('[ -]+', '_', col)) }}
{% endif %}{% endfor %}

from {{ patients }}  P

{% for table in tables %}
    left join {{ ref(table) }} "{{ table }}" ON ( "{{ table }}".Key = P.Key )
{% endfor %}

order by "target" desc
