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
    return subprocess.call(cmd, cwd=PROJECT_ROOT)


def remove_path(path: Path) -> None:
    if path.is_dir():
        shutil.rmtree(path, ignore_errors=True)
    elif path.exists():
        path.unlink()


def configure_options() -> None:
    if "{{ cookiecutter.auth_mode }}" != "oauth":
        remove_path(PROJECT_ROOT / PACKAGE_NAME / "auth")
        remove_path(PROJECT_ROOT / PACKAGE_NAME / "cache_handler.py")

    if not "{{ cookiecutter.enable_precommit }}".lower().startswith("y"):
        remove_path(PROJECT_ROOT / ".pre-commit-config.yaml")


def write_template_meta() -> None:
    template_meta = {
        "template": "APISDKTemplate",
        "template_repo": "gh:cabell132/CookiecutterTemplates",
        "synced_at": datetime.now(tz=timezone.utc).strftime("%Y-%m-%d"),
        "variables": {
            "project_slug": "{{ cookiecutter.project_slug }}",
            "python_version": "{{ cookiecutter.python_version }}",
            "service_name": "{{ cookiecutter.service_name }}",
            "auth_mode": "{{ cookiecutter.auth_mode }}",
            "auth_env_var_name": "{{ cookiecutter.auth_env_var_name }}",
            "enable_precommit": "{{ cookiecutter.enable_precommit }}",
            "full_name": "{{ cookiecutter.full_name }}",
            "email": "{{ cookiecutter.email }}",
        },
    }
    (PROJECT_ROOT / ".template.json").write_text(
        json.dumps(template_meta, indent=2) + "\n"
    )


def main() -> None:
    configure_options()
    write_template_meta()

    run(["git", "init"])
    run(["git", "add", "."])
    run(["git", "commit", "-m", "Initial scaffold from cookiecutter template"])

    if "{{ cookiecutter.enable_precommit }}".lower().startswith("y"):
        init_code = run(["uv", "tool", "run", "pre-commit", "install"])
        if init_code != 0:
            sys.stderr.write("Warning: failed to install pre-commit hooks.\n")

    print("\nNext steps:")
    print("  uv sync")
    print("  uv run poe test")


if __name__ == "__main__":
    main()
