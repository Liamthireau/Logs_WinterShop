{{
    config(
        materialized='table'
    )
}}

WITH parsed_logs AS (
    SELECT
        logs,

        -- Timestamp propre directement en format TIMESTAMP
        to_timestamp(
            substring(logs FROM '\[(\d{2}/[A-Za-z]{3}/\d{4}:\d{2}:\d{2}:\d{2})'),
            'DD/Mon/YYYY:HH24:MI:SS'
        ) AS log_timestamp,

        -- IP
        substring(logs FROM '^(\d+\.\d+\.\d+\.\d+)') AS ip,

        -- User authentifié (entre les deux " - ", si différent de "-")
        NULLIF(
            TRIM(substring(logs FROM '^\d+\.\d+\.\d+\.\d+ - ([^ ]+) \[')),
            '-'
        ) AS user_id,

        -- Méthode HTTP
        substring(logs FROM '"(GET|POST|PUT|DELETE|HEAD|OPTIONS|PATCH)') AS http_method,

        -- URL complète
        substring(logs FROM '"(?:GET|POST|PUT|DELETE|HEAD|OPTIONS|PATCH) ([^ ]+)') AS url,

        -- Code HTTP
        substring(logs FROM 'HTTP/1\.[01]"\s(\d{3})')::int AS status_code,

        -- Taille réponse (bytes)
        substring(logs FROM 'HTTP/1\.[01]"\s\d{3}\s(\d+)')::bigint AS bytes,

        -- Referer
        substring(logs FROM '\d{3}\s\d+\s"([^"]*)"') AS referer,

        -- User agent
        substring(logs FROM '"([^"]+)"$') AS user_agent

    FROM {{ source('prod', 'bronzetable') }}
)

SELECT
    -- =====================
    -- COLONNES DE BASE
    -- =====================
    log_timestamp,
    ip,
    user_id,
    http_method,
    url,
    status_code,
    bytes,
    referer,
    user_agent,

    -- =====================
    -- COLONNES DÉRIVÉES - URL
    -- =====================
    -- Catégorie de page (premier segment de l'URL)
    NULLIF(split_part(url, '/', 2), '') AS page_category,

    -- Nom du produit (deuxième segment de l'URL si présent)
    NULLIF(split_part(url, '/', 3), '') AS product_name,

    -- Paramètres de recherche interne
    CASE
        WHEN url LIKE '%search?q=%' 
        THEN replace(substring(url FROM 'q=([^&]+)'), '+', ' ')
        ELSE NULL
    END AS internal_search_query,

    -- =====================
    -- COLONNES DÉRIVÉES - STATUS
    -- =====================
    CASE
        WHEN status_code BETWEEN 200 AND 299 THEN 'success'
        WHEN status_code BETWEEN 300 AND 399 THEN 'redirect'
        WHEN status_code BETWEEN 400 AND 499 THEN 'client_error'
        WHEN status_code >= 500 THEN 'server_error'
        ELSE 'unknown'
    END AS status_category,

    status_code >= 400 AS is_error,

    -- =====================
    -- COLONNES DÉRIVÉES - REFERER
    -- =====================
    -- Est-ce une visite depuis Google ?
    referer ILIKE '%google.%' AS is_google_search,

    -- Est-ce une visite depuis un moteur de recherche ?
    (referer ILIKE '%google.%' 
     OR referer ILIKE '%bing.%' 
     OR referer ILIKE '%duckduckgo.%'
     OR referer ILIKE '%yahoo.%') AS is_search_engine,

    -- Requête Google extraite
    CASE
        WHEN referer ILIKE '%google.%' AND referer LIKE '%q=%'
        THEN replace(substring(referer FROM 'q=([^&]+)'), '+', ' ')
        ELSE NULL
    END AS google_query,

    -- Domaine du referer
    CASE
        WHEN referer IS NOT NULL AND referer != '-' AND referer != ''
        THEN substring(referer FROM 'https?://([^/]+)')
        ELSE NULL
    END AS referer_domain,

    -- Est-ce du trafic interne (depuis le site lui-même) ?
    referer ILIKE '%skishop.local%' AS is_internal_traffic,

    -- =====================
    -- COLONNES DÉRIVÉES - DEVICE & BROWSER
    -- =====================
    -- Type d'appareil
    CASE
        WHEN user_agent ILIKE '%iphone%' 
          OR user_agent ILIKE '%android%mobile%'
          OR user_agent ILIKE '%mobile%'
        THEN 'mobile'
        WHEN user_agent ILIKE '%ipad%'
          OR user_agent ILIKE '%tablet%'
          OR user_agent ILIKE '%SM-T%'
        THEN 'tablet'
        WHEN user_agent ILIKE '%smarttv%'
          OR user_agent ILIKE '%tizen%'
        THEN 'tv'
        ELSE 'desktop'
    END AS device_type,

    -- Système d'exploitation
    CASE
        WHEN user_agent ILIKE '%iphone%' OR user_agent ILIKE '%ipad%' THEN 'iOS'
        WHEN user_agent ILIKE '%android%' THEN 'Android'
        WHEN user_agent ILIKE '%windows nt%' THEN 'Windows'
        WHEN user_agent ILIKE '%linux%' AND user_agent NOT ILIKE '%android%' THEN 'Linux'
        WHEN user_agent ILIKE '%macintosh%' OR user_agent ILIKE '%mac os%' THEN 'MacOS'
        ELSE 'Other'
    END AS os,

    -- Navigateur
    CASE
        WHEN user_agent ILIKE '%edg/%' OR user_agent ILIKE '%edge/%' THEN 'Edge'
        WHEN user_agent ILIKE '%opr/%' OR user_agent ILIKE '%opera%' THEN 'Opera'
        WHEN user_agent ILIKE '%firefox/%' OR user_agent ILIKE '%librewolf%' THEN 'Firefox'
        WHEN user_agent ILIKE '%chrome/%' AND user_agent NOT ILIKE '%chromium%' THEN 'Chrome'
        WHEN user_agent ILIKE '%chromium%' THEN 'Chromium'
        WHEN user_agent ILIKE '%safari/%' AND user_agent NOT ILIKE '%chrome%' THEN 'Safari'
        ELSE 'Other'
    END AS browser,

    -- =====================
    -- COLONNES DÉRIVÉES - BOT DETECTION
    -- =====================
    (user_agent ILIKE '%bot%'
     OR user_agent ILIKE '%crawler%'
     OR user_agent ILIKE '%spider%'
     OR user_agent ILIKE '%googlebot%'
     OR user_agent ILIKE '%bingbot%'
     OR user_agent ILIKE '%ahrefsbot%'
     OR user_agent ILIKE '%semrushbot%'
     OR user_agent ILIKE '%headlesschrome%'
    ) AS is_bot,

    -- =====================
    -- COLONNES DÉRIVÉES - TEMPORELLES
    -- =====================
    DATE(log_timestamp) AS log_date,
    EXTRACT(HOUR FROM log_timestamp)::int AS hour_of_day,
    EXTRACT(DOW FROM log_timestamp)::int AS day_of_week,  -- 0=dimanche, 6=samedi
    TO_CHAR(log_timestamp, 'Day') AS day_name,
    EXTRACT(WEEK FROM log_timestamp)::int AS week_of_year,
    EXTRACT(MONTH FROM log_timestamp)::int AS month

FROM parsed_logs
WHERE log_timestamp IS NOT NULL
