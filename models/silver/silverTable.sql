SELECT
    -- Timestamp propre directement en format TIMESTAMP
    to_timestamp(
        substring(logs FROM '\[(\d{2}/[A-Za-z]{3}/\d{4}:\d{2}:\d{2}:\d{2})'),
        'DD/Mon/YYYY:HH24:MI:SS'
    ) AS log_timestamp,

    -- IP
    substring(logs FROM '^(\d+\.\d+\.\d+\.\d+)') AS ip,

    -- Méthode HTTP
    substring(logs FROM '"(GET|POST|PUT|DELETE|HEAD|OPTIONS)') AS http_method,

    -- URL
    substring(logs FROM '"(?:GET|POST|PUT|DELETE|HEAD|OPTIONS) ([^ ]+)') AS url,

    -- Code HTTP
    substring(logs FROM 'HTTP/1\.1"\s(\d{3})')::int AS status_code,

    -- Taille réponse (bytes)
    substring(logs FROM 'HTTP/1\.1"\s\d{3}\s(\d+)')::bigint AS bytes,

    -- Referer
    substring(logs FROM '"(http[^"]+)"') AS referer,

    -- User agent
    substring(logs FROM '"Mozilla[^"]+"$') AS user_agent,

    -- Device type
    CASE
        WHEN logs ILIKE '%iphone%' 
          OR logs ILIKE '%android%' 
          OR logs ILIKE '%mobile%' 
        THEN 'mobile'
        ELSE 'desktop'
    END AS device_type,

    -- OS
    CASE
        WHEN logs ILIKE '%iphone%' OR logs ILIKE '%ios%' THEN 'iOS'
        WHEN logs ILIKE '%android%' THEN 'Android'
        WHEN logs ILIKE '%windows%' THEN 'Windows'
        WHEN logs ILIKE '%linux%' THEN 'Linux'
        WHEN logs ILIKE '%mac os%' THEN 'MacOS'
        ELSE 'Other'
    END AS os,

    -- Browser
    CASE
        WHEN logs ILIKE '%edg/%' THEN 'Edge'
        WHEN logs ILIKE '%chrome/%' THEN 'Chrome'
        WHEN logs ILIKE '%firefox/%' OR logs ILIKE '%librewolf%' THEN 'Firefox'
        WHEN logs ILIKE '%safari/%' THEN 'Safari'
        ELSE 'Other'
    END AS browser

FROM {{ source('prod', 'bronzetable') }}
