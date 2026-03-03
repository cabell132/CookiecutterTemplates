{% if cookiecutter.include_docs == "mkdocs" -%}
# {{ cookiecutter.project_name }}

{{ cookiecutter.module_description }}
{% else -%}
<!-- Documentation disabled via cookiecutter option -->
{% endif -%}
