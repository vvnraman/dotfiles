import logging
from pathlib import Path
from typing import Annotated

import typer
from install_tool_lib import (  # pyright: ignore[reportImplicitRelativeImport]
    InstallValidationError,
    ToolInstallArgs,
    install_tool_with_mode,
)

from dotfiles.logging_config import configure_logging
from dotfiles.run_command import RunOutputError
from dotfiles.util import L


def _repo_project_dir() -> Path:
    return Path(__file__).resolve().parents[2]


def main(
    dev: bool = False,
    dry_run: Annotated[
        bool | None,
        typer.Option("--dry-run/--no-dry-run"),
    ] = None,
    dirty_install_path: Annotated[
        str | None,
        typer.Option(
            "--dirty-install-path",
            help="Custom non-default bin path that skips clean/branch checks",
        ),
    ] = None,
) -> None:
    configure_logging()
    resolved_dry_run = dry_run if dry_run is not None else (not dev)

    try:
        install_tool_with_mode(
            ToolInstallArgs(
                project_dir=_repo_project_dir(),
                dev=dev,
                dry_run=resolved_dry_run,
                dirty_install_path=dirty_install_path,
            )
        )
    except (InstallValidationError, RunOutputError) as error:
        logging.error(f"{L.E} {error}")
        raise typer.Exit(code=2) from error


if __name__ == "__main__":
    typer.run(main)
