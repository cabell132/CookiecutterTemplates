"""CLI entry point for {{ cookiecutter.project_name }}."""

from __future__ import annotations

try:
    import typer  # type: ignore[import-not-found]
except ImportError as exc:  # pragma: no cover
    msg = (
        "Typer is required for the CLI. Re-run cookiecutter enabling the CLI option "
        "or install typer."
    )
    raise RuntimeError(msg) from exc

from {{ cookiecutter.project_slug }} import __version__

app = typer.Typer(help="{{ cookiecutter.module_description }}")


@app.command()
def version() -> None:
    """Show the current package version."""
    typer.echo(__version__)


if __name__ == "__main__":
    app()
