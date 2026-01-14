{{ config(materialized='table') }}

select
    raw_line,
    ingestion_date
from bronze.raw_events