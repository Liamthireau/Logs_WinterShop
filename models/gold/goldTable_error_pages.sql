{{
    config(
        materialized='table'
    )
}}

SELECT
    url AS page,
    COUNT(*) AS nb_errors,
    COUNT(DISTINCT ip) AS nb_users_impacted
FROM {{ ref('silvertable') }}
WHERE status_code >= 400
GROUP BY url
ORDER BY nb_errors DESC
