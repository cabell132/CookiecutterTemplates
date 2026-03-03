from __future__ import annotations

import shutil
import subprocess
import sys
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


def main() -> None:
    configure_options()

    if "{{ cookiecutter.enable_precommit }}".lower().startswith("y"):
        init_code = run(["uv", "tool", "run", "pre-commit", "install"])
        if init_code != 0:
            sys.stderr.write("Warning: failed to install pre-commit hooks.\n")

    print("\nNext steps:")
    print("  uv sync")
    print("  uv run poe test")


if __name__ == "__main__":
    main()
