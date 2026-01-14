{{ config(materialized='table') }}

with hourly_users as (
    select
        date_trunc('hour', event_timestamp) as hour,
        count(distinct user_id) as users_count
    from {{ ref('silverTable') }}
    group by 1
)

select
    min(users_count) as min_users_per_hour,
    max(users_count) as max_users_per_hour,
    avg(users_count) as avg_users_per_hour
from hourly_users