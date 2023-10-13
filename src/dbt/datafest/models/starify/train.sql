-- depends_on: {{ ref('lhs-lc-ml-codes') }}
-- depends_on: {{ ref('lhs-stroke-ml-codes') }}

{# {% set columns = dbt_utils.get_column_values(target_lhs_dataset(), 'code') %} #}
{# {{ print(columns) }} #}
SELECT
    * 
FROM {{ ref('summary') }} WHERE 
	(target = 0 and %ID %FIND %SQL.SAMPLE( '{{unquotedref('summary')}}' , {{var('split-train-pct')}} , {{var('split-seed')}} ))
	OR 
	(target = 1 and %ID %FIND %SQL.SAMPLE( '{{unquotedref('summary')}}' , {{var('split-train-pct')}} , {{var('split-seed')}} ))


