"""Pre-generation hook: validate project slug and Python version."""

import re
import sys

SLUG_RE = re.compile(r"^[a-z][a-z0-9_]+$")


def main() -> None:
    """Validate cookiecutter inputs before generating the project."""
    project_slug = "{{ cookiecutter.project_slug }}"
    python_version = "{{ cookiecutter.python_version }}"

    if not SLUG_RE.match(project_slug):
        sys.stderr.write(
            f"ERROR: project_slug '{project_slug}' must be snake_case and start with a letter.\n"
        )
        sys.exit(1)

    if not re.match(r"^3\.(1[1-9]|[2-9][0-9])$", python_version):
        sys.stderr.write("ERROR: python_version should be >= 3.11 (e.g., 3.12).\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
