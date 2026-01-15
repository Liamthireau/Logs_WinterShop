{{
    config(
        materialized='table'
    )
}}

SELECT
    page_category,
    url AS page,
    product_name,
    COUNT(*) AS nb_hits,
    COUNT(DISTINCT ip) AS nb_users,
    SUM(bytes) AS total_bytes,
    AVG(bytes)::bigint AS avg_bytes
FROM {{ ref('silvertable') }}
WHERE url IS NOT NULL
  AND is_bot = FALSE
GROUP BY page_category, url, product_name
ORDER BY nb_hits DESC
