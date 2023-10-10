
WITH sales_fact AS (
  SELECT
    item_dim.id AS item_id,
    cat_dim.id AS cat_id,
    store_dim.id AS store_id,
    dept_dim.id AS dept_id,
    state_dim.id AS state_id,
    UNITS_SOLD,
    SELL_PRICE
  FROM {{ source('files', 'walmart') }} walmart
  LEFT JOIN {{ ref('item_dim') }} item_dim ON walmart.item_id = item_dim.item_id
  LEFT JOIN {{ ref('cat_dim') }} cat_dim ON walmart.cat_id = cat_dim.cat_id
  LEFT JOIN {{ ref('store_dim') }} store_dim ON walmart.store_id = store_dim.store_id
  LEFT JOIN {{ ref('dept_dim') }} dept_dim ON walmart.dept_id = dept_dim.dept_id
  LEFT JOIN {{ ref('state_dim') }} state_dim ON walmart.state_id = state_dim.state_id
)

SELECT *
FROM sales_fact
