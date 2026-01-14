{% macro extract_user_id(raw_col) %}
    regexp_extract({{ raw_col }}, 'user_id=([0-9]+)', 1)
{% endmacro %}

{% macro extract_email(raw_col) %}
    regexp_extract(
        {{ raw_col }},
        'email=([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})',
        1
    )
{% endmacro %}

{% macro extract_event(raw_col) %}
    regexp_extract({{ raw_col }}, 'event=([a-zA-Z_]+)', 1)
{% endmacro %}

{% macro extract_event_date(raw_col) %}
    regexp_extract({{ raw_col }}, 'date=([0-9]{4}-[0-9]{2}-[0-9]{2})', 1)
{% endmacro %}
