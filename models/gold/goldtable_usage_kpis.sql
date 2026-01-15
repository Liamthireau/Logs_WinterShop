{{
    config(
        materialized='table'
    )
}}

WITH base AS (
    SELECT
        log_timestamp,
        log_date,
        hour_of_day,
        ip,
        device_type
    FROM {{ ref('silvertable') }}
    WHERE is_bot = FALSE
),

-- Nombre de visiteurs par heure
per_hour AS (
    SELECT
        log_date,
        hour_of_day,
        COUNT(DISTINCT ip) AS users_per_hour
    FROM base
    GROUP BY log_date, hour_of_day
),

-- Sessions utilisateurs (timeout 30 minutes)
sessions AS (
    SELECT
        ip,
        log_timestamp,
        LAG(log_timestamp) OVER (PARTITION BY ip ORDER BY log_timestamp) AS previous_ts
    FROM base
),

session_durations AS (
    SELECT
        ip,
        EXTRACT(EPOCH FROM (log_timestamp - previous_ts)) AS duration_seconds
    FROM sessions
    WHERE previous_ts IS NOT NULL
      AND log_timestamp - previous_ts < INTERVAL '30 minutes'
),

device_split AS (
    SELECT
        device_type,
        COUNT(DISTINCT ip) AS users
    FROM base
    GROUP BY device_type
)

SELECT
    -- Trafic horaire
    (SELECT MIN(users_per_hour) FROM per_hour) AS min_users_per_hour,
    (SELECT MAX(users_per_hour) FROM per_hour) AS max_users_per_hour,
    (SELECT ROUND(AVG(users_per_hour), 2) FROM per_hour) AS avg_users_per_hour,

    -- Durée moyenne session en secondes
    (SELECT ROUND(AVG(duration_seconds), 2) FROM session_durations) AS avg_session_duration_seconds,

    -- Visiteurs par device type
    (SELECT COALESCE(users, 0) FROM device_split WHERE device_type = 'mobile') AS mobile_users,
    (SELECT COALESCE(users, 0) FROM device_split WHERE device_type = 'tablet') AS tablet_users,
    (SELECT COALESCE(users, 0) FROM device_split WHERE device_type = 'desktop') AS desktop_users,
    (SELECT COALESCE(users, 0) FROM device_split WHERE device_type = 'tv') AS tv_users,

    -- Total visiteurs uniques (hors bots)
    (SELECT COUNT(DISTINCT ip) FROM base) AS total_unique_users
