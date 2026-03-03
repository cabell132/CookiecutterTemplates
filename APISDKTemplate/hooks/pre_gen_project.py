import re
import sys

SLUG_RE = re.compile(r"^[a-z][a-z0-9_]+$")
PASCAL_RE = re.compile(r"^[A-Z][a-zA-Z0-9]+$")


def main() -> None:
    project_slug = "{{ cookiecutter.project_slug }}"
    python_version = "{{ cookiecutter.python_version }}"
    service_name = "{{ cookiecutter.service_name }}"

    if not SLUG_RE.match(project_slug):
        sys.stderr.write(
            f"ERROR: project_slug '{project_slug}' must be snake_case and start with a letter.\n"
        )
        sys.exit(1)

    if not re.match(r"^3\.(1[1-9]|[2-9][0-9])$", python_version):
        sys.stderr.write("ERROR: python_version should be >= 3.11 (e.g., 3.12).\n")
        sys.exit(1)

    if not PASCAL_RE.match(service_name):
        sys.stderr.write(
            f"ERROR: service_name '{service_name}' must be PascalCase (e.g., 'MyService').\n"
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
