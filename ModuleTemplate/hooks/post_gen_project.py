"""Post-generation hook: remove optional files and install pre-commit."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

PROJECT_ROOT = Path(".")
PACKAGE_NAME = "{{ cookiecutter.project_slug }}"


def run(cmd: list[str]) -> int:
    """Run a shell command and return exit code."""
    return subprocess.call(cmd, cwd=PROJECT_ROOT)


def remove_path(path: Path) -> None:
    """Remove a file or directory if it exists."""
    if path.is_dir():
        shutil.rmtree(path, ignore_errors=True)
    elif path.exists():
        path.unlink()


def configure_options() -> None:
    """Remove files based on cookiecutter options."""
    if "{{ cookiecutter.include_cli }}" != "typer":
        remove_path(PROJECT_ROOT / PACKAGE_NAME / "cli.py")

    if "{{ cookiecutter.include_docs }}" != "mkdocs":
        remove_path(PROJECT_ROOT / "docs" / "index.md")
        remove_path(PROJECT_ROOT / "mkdocs.yml")

    if "{{ cookiecutter.include_docker }}".lower().startswith("n"):
        remove_path(PROJECT_ROOT / "Dockerfile")
        remove_path(PROJECT_ROOT / ".dockerignore")

    if not "{{ cookiecutter.enable_precommit }}".lower().startswith("y"):
        remove_path(PROJECT_ROOT / ".pre-commit-config.yaml")


def write_template_meta() -> None:
    """Write .template.json with cookiecutter context for future syncs."""
    template_meta = {
        "template": "ModuleTemplate",
        "template_repo": "gh:cabell132/CookiecutterTemplates",
        "synced_at": datetime.now(tz=timezone.utc).strftime("%Y-%m-%d"),
        "variables": {
            "project_slug": "{{ cookiecutter.project_slug }}",
            "python_version": "{{ cookiecutter.python_version }}",
            "include_cli": "{{ cookiecutter.include_cli }}",
            "include_docs": "{{ cookiecutter.include_docs }}",
            "include_docker": "{{ cookiecutter.include_docker }}",
            "enable_precommit": "{{ cookiecutter.enable_precommit }}",
            "full_name": "{{ cookiecutter.full_name }}",
            "email": "{{ cookiecutter.email }}",
        },
    }
    (PROJECT_ROOT / ".template.json").write_text(json.dumps(template_meta, indent=2) + "\n")


def make_scripts_executable() -> None:
    """Ensure Pi hook scripts are executable."""
    for script in (PROJECT_ROOT / ".pi" / "hook" / "scripts").glob("*.sh"):
        script.chmod(script.stat().st_mode | 0o755)


def main() -> None:
    """Run post-generation configuration."""
    configure_options()
    write_template_meta()
    make_scripts_executable()

    run(["git", "init"])
    run(["git", "add", "."])
    run(["git", "commit", "-m", "Initial scaffold from cookiecutter template"])

    if "{{ cookiecutter.enable_precommit }}".lower().startswith("y"):
        try:
            init_code = run(["uv", "tool", "run", "pre-commit", "install"])
            if init_code != 0:
                sys.stderr.write("Warning: failed to install pre-commit hooks.\n")
        except FileNotFoundError:
            sys.stderr.write("Warning: uv not found; skipping pre-commit install.\n")

    print("\nNext steps:")
    print("  uv sync")
    print("  uv run poe test")


if __name__ == "__main__":
    main()
