SELECT logs, substring(logs FROM '\[(\d{2}/[A-Za-z]{3}/\d{4}:\d{2}:\d{2}:\d{2})') AS timestamp_extrait FROM {{ source('prod', 'bronzeTable')}}

