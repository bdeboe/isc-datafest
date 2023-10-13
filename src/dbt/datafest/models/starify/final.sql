{{
    config(
        materialized='table',
        indexes=[
            {'name': 'KeyIdx', 'columns': ['Key'], 'unique': True},
            {'name': 'TargetIdx', 'columns': ['target', 'Key']},
            {'name': 'PredictedIdx', 'columns': ['predicted', 'Key']},
            {'name': 'ProbabilityIdx', 'columns': ['probability', 'Key']},
        ]
    )
}}

SELECT predict.Key,
       predict.predicted,
       predict.probability,
       predict.target,
       {{ dbt_utils.star(ref('summary'), except=['Key', 'target']) }}
from {{ ref('predict') }} predict
join {{ ref('summary')}} summary using (Key)
order by probability desc
