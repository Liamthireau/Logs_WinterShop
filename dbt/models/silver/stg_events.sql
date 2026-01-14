{{ config(materialized='view') }}

select
    {{ extract_user_id('raw_line') }}::int     as user_id,
    {{ extract_email('raw_line') }}            as email,
    {{ extract_event('raw_line') }}            as event_type,
    {{ extract_event_date('raw_line') }}::date as event_date,
    raw_line
from {{ ref('src_raw_events') }}