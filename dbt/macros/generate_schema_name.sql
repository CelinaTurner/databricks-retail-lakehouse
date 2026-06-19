{#
  By default dbt builds schemas as <target_schema>_<custom_schema>. For a clean
  medallion layout we want models to land in exactly the schema named in their
  folder config (silver / gold), so this override returns the custom schema
  verbatim when one is set.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
