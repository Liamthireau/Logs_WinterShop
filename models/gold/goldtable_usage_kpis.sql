WITH base AS (
    SELECT
        log_timestamp,
        ip,
        device_type
    FROM {{ ref('silvertable') }}
),

-- Nombre de visiteurs par heure
per_hour AS (
    SELECT
        date_trunc('hour', log_timestamp) AS hour,
        COUNT(DISTINCT ip) AS users_per_hour
    FROM base
    GROUP BY hour
),

-- Sessions utilisateurs (timeout 30 minutes)
sessions AS (
    SELECT
        ip,
        log_timestamp,
        lag(log_timestamp) OVER (PARTITION BY ip ORDER BY log_timestamp) AS previous_ts
    FROM base
),

session_durations AS (
    SELECT
        ip,
        EXTRACT(EPOCH FROM (log_timestamp - previous_ts)) AS duration_seconds
    FROM sessions
    WHERE previous_ts IS NOT NULL
      AND log_timestamp - previous_ts < interval '30 minutes'
),

device_split AS (
    SELECT
        device_type,
        COUNT(DISTINCT ip) AS users
    FROM base
    GROUP BY device_type
)

SELECT
    -- trafic horaire
    (SELECT MIN(users_per_hour) FROM per_hour) AS min_users_per_hour,
    (SELECT MAX(users_per_hour) FROM per_hour) AS max_users_per_hour,
    (SELECT AVG(users_per_hour) FROM per_hour) AS avg_users_per_hour,

    -- durée moyenne session en secondes
    (SELECT AVG(duration_seconds) FROM session_durations) AS avg_session_duration_seconds,

    -- visiteurs mobile vs desktop
    (SELECT users FROM device_split WHERE device_type = 'mobile') AS mobile_users,
    (SELECT users FROM device_split WHERE device_type = 'desktop') AS desktop_users
