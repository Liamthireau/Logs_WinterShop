{{
    config(
        materialized='table'
    )
}}

SELECT
    page_category,
    url AS page,
    status_code,
    status_category,
    COUNT(*) AS nb_errors,
    COUNT(DISTINCT ip) AS nb_users_impacted
FROM {{ ref('silvertable') }}
WHERE is_error = TRUE
  AND is_bot = FALSE
GROUP BY page_category, url, status_code, status_category
ORDER BY nb_errors DESC
