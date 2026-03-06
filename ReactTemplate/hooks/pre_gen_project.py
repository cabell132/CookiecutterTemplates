"""Pre-generation hook: validate project slug."""

import re
import sys

SLUG_RE = re.compile(r"^[a-z][a-z0-9-]+$")


def main() -> None:
    """Validate cookiecutter inputs before generating the project."""
    project_slug = "{{ cookiecutter.project_slug }}"

    if not SLUG_RE.match(project_slug):
        sys.stderr.write(
            f"ERROR: project_slug '{project_slug}' must be kebab-case and start with a letter.\n"
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
