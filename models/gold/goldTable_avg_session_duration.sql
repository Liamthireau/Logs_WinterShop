{{ config(materialized='table') }}

with session_times as (
    select
        session_id,
        min(event_timestamp) as session_start,
        max(event_timestamp) as session_end
    from {{ ref('silverTable') }}
    group by 1
)

select
    avg(extract(epoch from (session_end - session_start))) as avg_session_duration_seconds
from session_times