"""Tests for baking the ModuleTemplate cookiecutter."""

from __future__ import annotations

from contextlib import contextmanager

import yaml
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
        assert ".github" in files
        assert "pyproject.toml" in files
        assert "uv.lock" in files
        assert "CLAUDE.md" in files
        assert "AGENTS.md" in files
        assert ".claude" in files
        assert "README.md" in files
        assert "LICENSE" in files
        assert "CHANGELOG.md" in files
        assert ".editorconfig" in files
        assert ".gitignore" in files
        assert "tests" in files
        assert "docs" in files

        pyproject = result.project_path.joinpath("pyproject.toml").read_text()
        assert "[build-system]" in pyproject
        assert "[tool.uv]" in pyproject
        assert "[tool.poe.tasks.test]" in pyproject
        assert "[tool.poe.tasks.check]" in pyproject
        assert "[tool.poe.tasks.format-check]" in pyproject
        assert "[tool.poe.tasks.audit]" in pyproject
        assert "[tool.ruff.lint]" in pyproject
        assert "[tool.ty.environment]" in pyproject
        assert "[tool.pydoclint]" in pyproject
        assert "typer" in pyproject
        assert "fail_under = 80" in pyproject

        ci_path = result.project_path / ".github" / "workflows" / "ci.yml"
        with ci_path.open() as workflow:
            data = yaml.safe_load(workflow)
        assert data["name"] == "CI"


def test_bake_has_agent_integrations(cookies):
    """Baked project includes Claude docs and Pi hooks."""
    with bake(cookies) as result:
        assert result.exit_code == 0

        claude_dir = result.project_path / ".claude"
        assert claude_dir.is_dir()
        assert (claude_dir / "settings.json").is_file()
        assert (claude_dir / "agents" / "python-pro.md").is_file()

        pi_hook_dir = result.project_path / ".pi" / "hook"
        assert (pi_hook_dir / "hooks.yaml").is_file()
        assert (pi_hook_dir / "scripts" / "ruff-check.sh").is_file()
        assert (pi_hook_dir / "scripts" / "enforce-uv.sh").is_file()

        claude_md = result.project_path.joinpath("CLAUDE.md").read_text()
        assert "uv run poe lint" in claude_md
        assert "uv run poe typecheck" in claude_md
        assert "uv run poe doclint" in claude_md


def test_bake_without_cli(cookies):
    """Baking with include_cli=none removes CLI file and script entry."""
    with bake(cookies, extra_context={"include_cli": "none"}) as result:
        assert result.exit_code == 0

        pkg_dir = result.project_path / "awesome_module"
        assert not (pkg_dir / "cli.py").exists()

        pyproject = result.project_path.joinpath("pyproject.toml").read_text()
        assert "typer" not in pyproject
        assert "[project.scripts]" not in pyproject


def test_bake_without_docs(cookies):
    """Baking with include_docs=none removes mkdocs but keeps standards docs."""
    with bake(cookies, extra_context={"include_docs": "none"}) as result:
        assert result.exit_code == 0

        assert not (result.project_path / "mkdocs.yml").exists()
        assert not (result.project_path / "docs" / "index.md").exists()

        # Standards docs should still be present
        assert (result.project_path / "docs" / "README.md").is_file()
        assert (result.project_path / "docs" / "standards" / "error-handling.md").is_file()
        assert (result.project_path / "docs" / "standards" / "testing-strategy.md").is_file()
        assert (result.project_path / "docs" / "decisions" / "001-initial-tooling.md").is_file()
        assert (result.project_path / "docs" / "git" / "naming-conventions.md").is_file()

        pyproject = result.project_path.joinpath("pyproject.toml").read_text()
        assert "mkdocs" not in pyproject


def test_bake_without_docker(cookies):
    """Baking with include_docker=n removes Dockerfile and .dockerignore."""
    with bake(cookies, extra_context={"include_docker": "n"}) as result:
        assert result.exit_code == 0
        assert not (result.project_path / "Dockerfile").exists()
        assert not (result.project_path / ".dockerignore").exists()


def test_bake_with_docker(cookies):
    """Baking with include_docker=y includes Dockerfile and .dockerignore."""
    with bake(cookies, extra_context={"include_docker": "y"}) as result:
        assert result.exit_code == 0
        assert (result.project_path / "Dockerfile").is_file()
        assert (result.project_path / ".dockerignore").is_file()


def test_bake_without_precommit(cookies):
    """Baking with enable_precommit=n removes pre-commit config."""
    with bake(cookies, extra_context={"enable_precommit": "n"}) as result:
        assert result.exit_code == 0
        assert not (result.project_path / ".pre-commit-config.yaml").exists()


def test_bake_all_licenses(cookies):
    """Baking with each license option produces a valid LICENSE file."""
    for license_choice in ["MIT", "Apache-2.0", "Proprietary"]:
        with bake(cookies, extra_context={"license": license_choice}) as result:
            assert result.exit_code == 0
            license_text = result.project_path.joinpath("LICENSE").read_text()
            assert len(license_text) > 0


def test_bake_has_exceptions_module(cookies):
    """Baked project includes exceptions.py with base exception class."""
    with bake(cookies) as result:
        assert result.exit_code == 0

        pkg_dir = result.project_path / "awesome_module"
        assert (pkg_dir / "exceptions.py").is_file()

        exc_content = (pkg_dir / "exceptions.py").read_text()
        assert "AwesomeModuleError" in exc_content
        assert "AwesomeModuleValueError" in exc_content
        assert "AwesomeModuleRuntimeError" in exc_content

        init_content = (pkg_dir / "__init__.py").read_text()
        assert "AwesomeModuleError" in init_content


def test_bake_has_main_module(cookies):
    """Baked project includes __main__.py for python -m support."""
    with bake(cookies) as result:
        assert result.exit_code == 0

        pkg_dir = result.project_path / "awesome_module"
        assert (pkg_dir / "__main__.py").is_file()


def test_bake_smoke_test_exists(cookies):
    """Baked project includes a smoke test with exception import."""
    with bake(cookies) as result:
        assert result.exit_code == 0
        test_file = result.project_path / "tests" / "test_smoke.py"
        assert test_file.is_file()
        content = test_file.read_text()
        assert "test_version" in content
        assert "test_base_exception_importable" in content


def test_bake_has_changelog(cookies):
    """Baked project includes a CHANGELOG.md."""
    with bake(cookies) as result:
        assert result.exit_code == 0
        changelog = result.project_path / "CHANGELOG.md"
        assert changelog.is_file()
        content = changelog.read_text()
        assert "Keep a Changelog" in content


def test_bake_gitignore_does_not_exclude_uv_lock(cookies):
    """uv.lock should not be in .gitignore (lock files should be committed)."""
    with bake(cookies) as result:
        assert result.exit_code == 0
        gitignore = result.project_path.joinpath(".gitignore").read_text()
        assert "uv.lock" not in gitignore


def test_bake_precommit_config_has_ruff_ty_pydoclint(cookies):
    """Pre-commit config includes ruff, ty, pydoclint, and security hooks."""
    with bake(cookies) as result:
        assert result.exit_code == 0
        config = result.project_path.joinpath(".pre-commit-config.yaml").read_text()
        assert "ruff" in config
        assert "ty" in config
        assert "pydoclint" in config
        assert "check-ast" in config
        assert "check-merge-conflict" in config
        assert "detect-private-key" in config
