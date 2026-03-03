ARG PYTHON_VERSION="{{ cookiecutter.python_version }}"
FROM python:${PYTHON_VERSION}-slim AS base
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
RUN useradd --create-home appuser
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --no-dev --frozen
COPY . .
USER appuser
{% if cookiecutter.include_cli == "typer" -%}
CMD ["uv", "run", "{{ cookiecutter.project_slug.replace('_', '-') }}", "version"]
{% else -%}
CMD ["uv", "run", "python", "-m", "{{ cookiecutter.project_slug }}"]
{% endif -%}
