"""Post-generation hook: remove optional files and install dependencies."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

PROJECT_ROOT = Path(".")
PACKAGE_MANAGER = "{{ cookiecutter.node_package_manager }}"


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
    # Playwright / E2E
    if "{{ cookiecutter.include_playwright }}" != "yes":
        remove_path(PROJECT_ROOT / "e2e")
        remove_path(PROJECT_ROOT / "playwright.config.ts")

    # Docker
    if "{{ cookiecutter.include_docker }}" != "yes":
        remove_path(PROJECT_ROOT / "Dockerfile")
        remove_path(PROJECT_ROOT / ".dockerignore")

    # Pre-commit (husky)
    if "{{ cookiecutter.enable_precommit }}" != "yes":
        remove_path(PROJECT_ROOT / ".husky")

    # Docs
    if "{{ cookiecutter.include_docs }}" != "yes":
        remove_path(PROJECT_ROOT / "docs")

    # Router
    if "{{ cookiecutter.include_router }}" != "yes":
        remove_path(PROJECT_ROOT / "src" / "app" / "router.tsx")

    # AI tools — Claude
    ai_tools = "{{ cookiecutter.ai_tools }}"
    if ai_tools not in ("all", "claude"):
        remove_path(PROJECT_ROOT / ".claude")
        remove_path(PROJECT_ROOT / "CLAUDE.md")
        remove_path(PROJECT_ROOT / "AGENTS.md")

    # AI tools — Cursor
    if ai_tools not in ("all", "cursor"):
        remove_path(PROJECT_ROOT / ".cursor")

    # AI tools — Copilot
    if ai_tools not in ("all", "copilot"):
        remove_path(PROJECT_ROOT / ".github" / "copilot-instructions.md")


def _runner() -> list[str]:
    """Get the package runner command (bunx, pnpx, or npx)."""
    if PACKAGE_MANAGER == "bun":
        return ["bunx"]
    if PACKAGE_MANAGER == "pnpm":
        return ["pnpm", "exec"]
    return ["npx"]


def format_code() -> None:
    """Run Biome to format and lint-fix generated code."""
    try:
        # Stage files so Biome VCS integration can see them
        run(["git", "add", "."])
        # Run twice: first pass fixes lint issues that may break formatting,
        # second pass fixes the resulting formatting issues
        run([*_runner(), "biome", "check", "--write", "."])
        run([*_runner(), "biome", "check", "--write", "."])
    except FileNotFoundError:
        pass


def install_dependencies() -> None:
    """Install project dependencies using the chosen package manager."""
    if PACKAGE_MANAGER == "bun":
        cmd = ["bun", "install"]
    elif PACKAGE_MANAGER == "pnpm":
        cmd = ["pnpm", "install"]
    else:
        cmd = ["npm", "install"]

    try:
        code = run(cmd)
        if code != 0:
            sys.stderr.write(f"Warning: '{' '.join(cmd)}' exited with code {code}.\n")
    except FileNotFoundError:
        sys.stderr.write(f"Warning: {PACKAGE_MANAGER} not found; skipping install.\n")


def setup_git() -> None:
    """Initialize git repository."""
    try:
        run(["git", "init"])
    except FileNotFoundError:
        sys.stderr.write("Warning: git not found; skipping git init.\n")


def setup_husky() -> None:
    """Initialize husky for pre-commit hooks."""
    if "{{ cookiecutter.enable_precommit }}" != "yes":
        return

    try:
        code = run([*_runner(), "husky", "init"])
        if code != 0:
            sys.stderr.write("Warning: failed to initialize husky.\n")
    except FileNotFoundError:
        sys.stderr.write(f"Warning: {PACKAGE_MANAGER} runner not found; skipping husky init.\n")


def write_template_meta() -> None:
    """Write .template.json with cookiecutter context for future syncs."""
    template_meta = {
        "template": "ReactTemplate",
        "template_repo": "gh:cabell132/CookiecutterTemplates",
        "synced_at": datetime.now(tz=timezone.utc).strftime("%Y-%m-%d"),
        "variables": {
            "project_slug": "{{ cookiecutter.project_slug }}",
            "node_package_manager": "{{ cookiecutter.node_package_manager }}",
            "include_tanstack_query": "{{ cookiecutter.include_tanstack_query }}",
            "include_zustand": "{{ cookiecutter.include_zustand }}",
            "include_router": "{{ cookiecutter.include_router }}",
            "include_shadcn": "{{ cookiecutter.include_shadcn }}",
            "include_playwright": "{{ cookiecutter.include_playwright }}",
            "include_docker": "{{ cookiecutter.include_docker }}",
            "enable_precommit": "{{ cookiecutter.enable_precommit }}",
            "ai_tools": "{{ cookiecutter.ai_tools }}",
            "full_name": "{{ cookiecutter.full_name }}",
            "email": "{{ cookiecutter.email }}",
        },
    }
    (PROJECT_ROOT / ".template.json").write_text(
        json.dumps(template_meta, indent=2) + "\n"
    )


def main() -> None:
    """Run post-generation configuration."""
    configure_options()
    write_template_meta()
    setup_git()
    install_dependencies()
    format_code()
    setup_husky()

    pm = PACKAGE_MANAGER
    print("\n" + "=" * 50)
    print(f"  Project '{{ cookiecutter.project_slug }}' created!")
    print("=" * 50)
    print("\nNext steps:")
    print(f"  cd {{ cookiecutter.project_slug }}")
    print(f"  {pm} run dev")
    print(f"\nQuality gates:")
    print(f"  {pm} run typecheck    # Type check")
    print(f"  {pm} run lint         # Biome lint")
    print(f"  {pm} run test         # Run tests")
    print(f"  {pm} run check        # All gates")


if __name__ == "__main__":
    main()
