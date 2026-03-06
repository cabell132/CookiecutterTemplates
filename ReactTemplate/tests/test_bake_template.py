"""Tests for baking the ReactTemplate cookiecutter."""

from __future__ import annotations

import json
from contextlib import contextmanager

from cookiecutter.utils import rmtree


@contextmanager
def bake(cookies, *args, **kwargs):
    """Bake a cookiecutter template in a temp dir and clean up afterwards."""
    result = cookies.bake(*args, **kwargs)
    try:
        yield result
    finally:
        rmtree(str(result.project_path))


def test_bake_default(cookies):
    """Baking with defaults produces a valid project."""
    with bake(cookies) as result:
        assert result.project_path.is_dir()
        assert result.exit_code == 0

        files = {f.name for f in result.project_path.iterdir()}
        assert "package.json" in files
        assert "tsconfig.json" in files
        assert "vite.config.ts" in files
        assert "vitest.config.ts" in files
        assert "biome.json" in files
        assert "index.html" in files
        assert ".editorconfig" in files
        assert ".gitignore" in files
        assert "README.md" in files
        assert "LICENSE" in files
        assert "CHANGELOG.md" in files
        assert "CLAUDE.md" in files
        assert "AGENTS.md" in files
        assert ".claude" in files
        assert ".github" in files
        assert "src" in files


def test_bake_package_json_valid(cookies):
    """Baked package.json is valid JSON."""
    with bake(cookies) as result:
        assert result.exit_code == 0
        pkg = json.loads(result.project_path.joinpath("package.json").read_text())
        assert pkg["name"] == "my-app"
        assert "react" in pkg["dependencies"]
        assert "react-dom" in pkg["dependencies"]
        assert "zod" in pkg["dependencies"]
        assert "vitest" in pkg["devDependencies"]
        assert "@biomejs/biome" in pkg["devDependencies"]


def test_bake_package_json_valid_all_no(cookies):
    """package.json is valid JSON when all optional deps are disabled."""
    with bake(
        cookies,
        extra_context={
            "include_tanstack_query": "no",
            "include_zustand": "no",
            "include_router": "no",
            "include_shadcn": "no",
            "include_playwright": "no",
            "enable_precommit": "no",
        },
    ) as result:
        assert result.exit_code == 0
        pkg = json.loads(result.project_path.joinpath("package.json").read_text())
        assert "@tanstack/react-query" not in pkg["dependencies"]
        assert "zustand" not in pkg["dependencies"]
        assert "react-router" not in pkg["dependencies"]
        assert "@radix-ui/react-slot" not in pkg["dependencies"]
        assert "@playwright/test" not in pkg["devDependencies"]
        assert "husky" not in pkg["devDependencies"]
        assert "lint-staged" not in pkg


def test_bake_package_json_with_all_options(cookies):
    """package.json is valid JSON when all optional deps are enabled."""
    with bake(
        cookies,
        extra_context={
            "include_tanstack_query": "yes",
            "include_zustand": "yes",
            "include_router": "yes",
            "include_shadcn": "yes",
            "include_playwright": "yes",
            "enable_precommit": "yes",
        },
    ) as result:
        assert result.exit_code == 0
        pkg = json.loads(result.project_path.joinpath("package.json").read_text())
        assert "@tanstack/react-query" in pkg["dependencies"]
        assert "zustand" in pkg["dependencies"]
        assert "react-router" in pkg["dependencies"]
        assert "@radix-ui/react-slot" in pkg["dependencies"]
        assert "@playwright/test" in pkg["devDependencies"]
        assert "husky" in pkg["devDependencies"]
        assert "lint-staged" in pkg


def test_bake_all_licenses(cookies):
    """Each license option produces a non-empty LICENSE file."""
    for license_choice in ["MIT", "Apache-2.0", "Proprietary"]:
        with bake(cookies, extra_context={"license": license_choice}) as result:
            assert result.exit_code == 0
            license_text = result.project_path.joinpath("LICENSE").read_text()
            assert len(license_text.strip()) > 0


def test_bake_all_package_managers(cookies):
    """Each package manager produces correct audit script."""
    for pm in ["bun", "pnpm", "npm"]:
        with bake(cookies, extra_context={"node_package_manager": pm}) as result:
            assert result.exit_code == 0
            pkg = json.loads(result.project_path.joinpath("package.json").read_text())
            audit_cmd = pkg["scripts"]["audit"]
            assert pm in audit_cmd
            if pm == "bun":
                assert "pm audit" in audit_cmd


def test_bake_without_playwright(cookies):
    """Baking with include_playwright=no removes e2e and playwright config."""
    with bake(cookies, extra_context={"include_playwright": "no"}) as result:
        assert result.exit_code == 0
        assert not (result.project_path / "e2e").exists()
        assert not (result.project_path / "playwright.config.ts").exists()


def test_bake_without_docker(cookies):
    """Baking with include_docker=no removes Dockerfile and .dockerignore."""
    with bake(cookies, extra_context={"include_docker": "no"}) as result:
        assert result.exit_code == 0
        assert not (result.project_path / "Dockerfile").exists()
        assert not (result.project_path / ".dockerignore").exists()


def test_bake_with_docker(cookies):
    """Baking with include_docker=yes includes Dockerfile and .dockerignore."""
    with bake(cookies, extra_context={"include_docker": "yes"}) as result:
        assert result.exit_code == 0
        assert (result.project_path / "Dockerfile").is_file()
        assert (result.project_path / ".dockerignore").is_file()


def test_bake_without_precommit(cookies):
    """Baking with enable_precommit=no removes .husky."""
    with bake(cookies, extra_context={"enable_precommit": "no"}) as result:
        assert result.exit_code == 0
        assert not (result.project_path / ".husky").exists()


def test_bake_without_docs(cookies):
    """Baking with include_docs=no removes docs directory."""
    with bake(cookies, extra_context={"include_docs": "no"}) as result:
        assert result.exit_code == 0
        assert not (result.project_path / "docs").exists()


def test_bake_with_docs(cookies):
    """Baking with include_docs=yes includes docs with standards."""
    with bake(cookies) as result:
        assert result.exit_code == 0
        assert (result.project_path / "docs" / "decisions" / "001-initial-tooling.md").is_file()
        assert (result.project_path / "docs" / "standards" / "error-handling.md").is_file()
        assert (result.project_path / "docs" / "standards" / "testing-strategy.md").is_file()
        assert (result.project_path / "docs" / "standards" / "logging-strategy.md").is_file()
        assert (result.project_path / "docs" / "git" / "naming-conventions.md").is_file()


def test_bake_without_router(cookies):
    """Baking with include_router=no removes router.tsx."""
    with bake(cookies, extra_context={"include_router": "no"}) as result:
        assert result.exit_code == 0
        assert not (result.project_path / "src" / "app" / "router.tsx").exists()


def test_bake_with_router(cookies):
    """Baking with include_router=yes keeps router.tsx."""
    with bake(cookies, extra_context={"include_router": "yes"}) as result:
        assert result.exit_code == 0
        assert (result.project_path / "src" / "app" / "router.tsx").is_file()


def test_bake_claude_integration(cookies):
    """Claude integration is present when ai_tools includes claude."""
    for ai_tools in ["all", "claude"]:
        with bake(cookies, extra_context={"ai_tools": ai_tools}) as result:
            assert result.exit_code == 0
            assert (result.project_path / ".claude" / "settings.json").is_file()
            assert (result.project_path / ".claude" / "agents" / "react-pro.md").is_file()
            assert (result.project_path / ".claude" / "scripts" / "biome-format.sh").is_file()
            assert (result.project_path / "CLAUDE.md").is_file()
            assert (result.project_path / "AGENTS.md").is_file()


def test_bake_no_claude_when_none(cookies):
    """Claude integration is absent when ai_tools=none."""
    with bake(cookies, extra_context={"ai_tools": "none"}) as result:
        assert result.exit_code == 0
        assert not (result.project_path / ".claude").exists()
        assert not (result.project_path / "CLAUDE.md").exists()
        assert not (result.project_path / "AGENTS.md").exists()


def test_bake_cursor_rules(cookies):
    """Cursor rules present when ai_tools includes cursor."""
    for ai_tools in ["all", "cursor"]:
        with bake(cookies, extra_context={"ai_tools": ai_tools}) as result:
            assert result.exit_code == 0
            assert (result.project_path / ".cursor" / "rules" / "react-typescript.mdc").is_file()


def test_bake_no_cursor_when_none(cookies):
    """Cursor rules absent when ai_tools=none."""
    with bake(cookies, extra_context={"ai_tools": "none"}) as result:
        assert result.exit_code == 0
        assert not (result.project_path / ".cursor").exists()


def test_bake_copilot_instructions(cookies):
    """Copilot instructions present when ai_tools includes copilot."""
    for ai_tools in ["all", "copilot"]:
        with bake(cookies, extra_context={"ai_tools": ai_tools}) as result:
            assert result.exit_code == 0
            assert (result.project_path / ".github" / "copilot-instructions.md").is_file()


def test_bake_no_copilot_when_none(cookies):
    """Copilot instructions absent when ai_tools=none."""
    with bake(cookies, extra_context={"ai_tools": "none"}) as result:
        assert result.exit_code == 0
        assert not (result.project_path / ".github" / "copilot-instructions.md").exists()


def test_bake_feature_structure(cookies):
    """Feature-based src/ structure is correct."""
    with bake(cookies) as result:
        assert result.exit_code == 0
        example = result.project_path / "src" / "features" / "example"
        assert (example / "components" / "ExampleFeature.tsx").is_file()
        assert (example / "hooks" / "useExample.ts").is_file()
        assert (example / "schemas" / "example.schema.ts").is_file()
        assert (example / "__tests__" / "ExampleFeature.test.tsx").is_file()
        assert (example / "index.ts").is_file()


def test_bake_error_hierarchy(cookies):
    """Error hierarchy present in src/lib/errors.ts."""
    with bake(cookies) as result:
        assert result.exit_code == 0
        errors_file = result.project_path / "src" / "lib" / "errors.ts"
        assert errors_file.is_file()
        content = errors_file.read_text()
        assert "AppError" in content
        assert "ValidationError" in content
        assert "RuntimeError" in content


def test_bake_no_unresolved_jinja(cookies):
    """No unresolved Jinja2 templates in baked output."""
    with bake(cookies) as result:
        assert result.exit_code == 0

        for path in result.project_path.rglob("*"):
            if path.is_file() and path.suffix in (
                ".ts",
                ".tsx",
                ".json",
                ".md",
                ".html",
                ".yml",
                ".yaml",
                ".sh",
                ".cjs",
                ".mdc",
            ):
                try:
                    content = path.read_text(encoding="utf-8")
                except UnicodeDecodeError:
                    continue
                assert "{{" not in content or "{%" not in content, (
                    f"Unresolved Jinja2 in {path.relative_to(result.project_path)}"
                )


def test_bake_has_changelog(cookies):
    """Baked project includes a CHANGELOG.md."""
    with bake(cookies) as result:
        assert result.exit_code == 0
        changelog = result.project_path / "CHANGELOG.md"
        assert changelog.is_file()
        content = changelog.read_text()
        assert "Keep a Changelog" in content
