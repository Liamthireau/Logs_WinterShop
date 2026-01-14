SELECT
    url AS page,
    COUNT(*) AS nb_hits,
    COUNT(DISTINCT ip) AS nb_users
FROM {{ ref('silvertable') }}
WHERE url IS NOT NULL
GROUP BY url
ORDER BY nb_hits DESC