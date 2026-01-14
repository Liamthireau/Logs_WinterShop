{{ config(materialized='table') }}

select
    is_mobile,
    count(distinct user_id) as users_count
from {{ ref('silverTable') }}
group by 1