{{
    config(
        materialized='table'
    )
}}

WITH referer_stats AS (
    SELECT
        'referer' AS source_type,
        referer_domain AS source_value,
        is_search_engine,
        COUNT(*) AS nb_hits,
        COUNT(DISTINCT ip) AS nb_users
    FROM {{ ref('silvertable') }}
    WHERE referer_domain IS NOT NULL
      AND is_internal_traffic = FALSE
      AND is_bot = FALSE
    GROUP BY referer_domain, is_search_engine
),

google_queries_stats AS (
    SELECT
        'google_query' AS source_type,
        google_query AS source_value,
        TRUE AS is_search_engine,
        COUNT(*) AS nb_hits,
        COUNT(DISTINCT ip) AS nb_users
    FROM {{ ref('silvertable') }}
    WHERE google_query IS NOT NULL
      AND is_bot = FALSE
    GROUP BY google_query
)

SELECT * FROM referer_stats
UNION ALL
SELECT * FROM google_queries_stats
ORDER BY source_type, nb_hits DESC
