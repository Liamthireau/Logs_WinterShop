WITH base AS (
    SELECT
        referer,
        ip
    FROM {{ ref('silvertable') }}
    WHERE referer IS NOT NULL
),

-- Partie 1 : volumes par referer
referer_agg AS (
    SELECT
        'referer' AS source_type,
        referer AS source_value,
        COUNT(*) AS nb_hits,
        COUNT(DISTINCT ip) AS nb_users
    FROM base
    GROUP BY referer
),

-- Partie 2 : requêtes Google
google_queries AS (
    SELECT
        'google_query' AS source_type,
        replace(
            substring(referer FROM 'q=([^&]+)'),
            '+',
            ' '
        ) AS source_value,
        COUNT(*) AS nb_hits,
        COUNT(DISTINCT ip) AS nb_users
    FROM base
    WHERE referer ILIKE '%google.%'
      AND referer ILIKE '%search%'
      AND referer ILIKE '%q=%'
    GROUP BY source_value
)

-- Résultat final
SELECT * FROM referer_agg
UNION ALL
SELECT * FROM google_queries
ORDER BY source_type, nb_hits DESC
