{{ config(materialized='table') }}

select
    page_url,
    count(*) as error_count
from {{ ref('silverTable') }}
where http_status >= 400
group by 1
order by error_count desc