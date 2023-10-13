-- depends_on: {{ ref('train') }}

{{
    config(
        materialized='table',
        indexes=[
            {'name': 'KeyIdx', 'columns': ['Key'], 'unique': True},
            {'name': 'TargetIdx', 'columns': ['target', 'Key']},
            {'name': 'PredictedIdx', 'columns': ['predicted'], 'data': ['Key', 'probability']},
            {'name': 'ProbabilityIdx', 'columns': ['probability'], 'data': ['Key', 'predicted']},
        ]
    )
}}
{%- set model_name = this.schema ~ '_ml_model' %}

select
    Key,
    target,
    predict({{ model_name }}) as predicted,
    probability({{ model_name }}) as probability
from {{ ref('summary') }}
