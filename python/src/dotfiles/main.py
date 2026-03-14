import logging
import sys
from pathlib import Path
from typing import Annotated

import typer

from dotfiles.logging_config import configure_logging
from dotfiles.nvim import (
    NvimInfoArgs,
    NvimSyncWithMimicArgs,
    nvim_info,
    nvim_sync_with_mimic,
)
from dotfiles.paths import (
    SourceRootResolutionError,
    resolve_project_dir,
    set_source_root_override,
    show_project_dir_discovery,
)
from dotfiles.publish import PublishArgs, publish_with_config
from dotfiles.run_command import RunOutputError, run_only
from dotfiles.util import L

PROJECT_NAME = "dotfiles"

HOME_DIR = Path.home()
NVIM_CONFIG_DIR = HOME_DIR / ".config" / "nvim"


NVIM_COMMAND_HELP = """Sync neovim config directory into chezmoi source state.

\b
Sync plan:
  after/          remove, re-add
  init.lua        copy if runtime file changed
  lazy-lock.json  copy if runtime file changed
  lua/            sync
    - preserve chezmoi templates
    - skip runtime symlinks (resolved templates)
    - remove missing runtime files from source
    - remove missing runtime dirs from source
    - copy runtime files if changed
  README.rst      copy if runtime file changed
  stylua.toml     copy if runtime file changed
"""


def _project_dir() -> Path:
    try:
        return resolve_project_dir()
    except SourceRootResolutionError as error:
        logging.error(f"{L.E} {error}")
        raise typer.Exit(code=2) from error


def _docs_dir() -> Path:
    return _project_dir() / "docs"


def _build_dir() -> Path:
    return _docs_dir() / "_build"


def _html_dir() -> Path:
    return _build_dir() / "html"


def _configure_app_context(
    source_root: Annotated[
        str | None,
        typer.Option(
            "--source-root",
            help="Dotfiles git root containing .chezmoiroot/.git",
        ),
    ] = None,
    show_source_discovery: Annotated[
        bool,
        typer.Option(
            "--show-source-discovery",
            help="Resolve and show source root discovery steps, then exit",
        ),
    ] = False,
) -> None:
    configure_logging()
    set_source_root_override(source_root)
    if not show_source_discovery:
        return

    try:
        project_dir = show_project_dir_discovery(
            lambda step: logging.info(f"{L.B} {step}")
        )
    except SourceRootResolutionError as error:
        logging.error(f"{L.E} {error}")
        raise typer.Exit(code=2) from error

    logging.info(f"{L.C} Resolved source root = {project_dir}")
    raise typer.Exit(code=0)


app = typer.Typer(
    callback=_configure_app_context,
    invoke_without_command=True,
    no_args_is_help=True,
)
nvim_app = typer.Typer(help="Neovim config sync and info commands")
app.add_typer(nvim_app, name="nvim")


@app.command()
def info():
    project_dir = _project_dir()
    docs_dir = _docs_dir()
    build_dir = _build_dir()
    html_dir = _html_dir()
    logging.info(f"{L.A} Project        = {PROJECT_NAME}")
    logging.info(f"{L.B} Project dir    = {project_dir}")
    logging.info(f"{L.B} Docs dir       = {docs_dir}")
    logging.info(f"{L.B} Build dir      = {build_dir}")
    logging.info(f"{L.B} HTML dir       = {html_dir}")


@app.command()
def docs():
    docs_dir = _docs_dir()
    build_dir = _build_dir()
    logging.info(f"{L.A} Building docs for {PROJECT_NAME}")
    args = [
        sys.executable,
        "-m",
        "sphinx",
        "--builder",
        "html",
        str(docs_dir),
        str(build_dir),
    ]
    try:
        run_only(args)
    except RunOutputError as error:
        logging.error(f"{L.E} {error}")
        raise typer.Exit(code=2) from error


@app.command()
def live():
    docs_dir = _docs_dir()
    html_dir = _html_dir()
    logging.info(f"{L.A} Building livedocs for {PROJECT_NAME}")
    args = [
        sys.executable,
        "-m",
        "sphinx_autobuild",
        "--port",
        "0",
        "--open-browser",
        str(docs_dir),
        str(html_dir),
    ]
    try:
        run_only(args)
    except RunOutputError as error:
        logging.error(f"{L.E} {error}")
        raise typer.Exit(code=2) from error


@app.command()
def clean():
    docs_dir = _docs_dir()
    build_dir = _build_dir()
    logging.info(f"{L.A} Cleaning docs for {PROJECT_NAME}")
    args = [
        sys.executable,
        "-m",
        "sphinx",
        "-M",
        "clean",
        str(docs_dir),
        str(build_dir),
    ]
    try:
        run_only(args)
    except RunOutputError as error:
        logging.error(f"{L.E} {error}")
        raise typer.Exit(code=2) from error


@app.command()
def publish(
    dry_run: bool = True,
    override_branch: str | None = None,
    remote_name: str | None = None,
    dotfiles_repo: str | None = None,
    github_url: str | None = None,
    publish_host: str | None = None,
) -> None:
    project_dir = _project_dir()
    logging.info(f"{L.A} Publishing docs for {PROJECT_NAME}")
    try:
        publish_with_config(
            PublishArgs(
                project_dir=project_dir,
                dry_run=dry_run,
                override_branch=override_branch,
                remote_name=remote_name,
                dotfiles_repo=dotfiles_repo,
                github_url=github_url,
                publish_host=publish_host,
            )
        )
    except RunOutputError as error:
        logging.error(f"{L.E} {error}")
        raise typer.Exit(code=2) from error


@nvim_app.command("sync", help=NVIM_COMMAND_HELP)
def nvim_sync_command(
    dry_run: bool = True,
    mimic: bool = False,
    nvim_config_dir: str | None = None,
    log_unchanged_info: bool = False,
    override_branch_name: Annotated[
        str | None,
        typer.Option("--override-branch-name", "--override-nvim-branch"),
    ] = None,
):
    project_dir = _project_dir()
    """Sync runtime nvim config into local chezmoi state."""
    logging.info(f"{L.A} Syncing with neovim config")
    try:
        nvim_sync_with_mimic(
            NvimSyncWithMimicArgs(
                dry_run=dry_run,
                mimic=mimic,
                nvim_config_dir=nvim_config_dir,
                override_branch_name=override_branch_name,
                log_unchanged_info=log_unchanged_info,
                project_dir=project_dir,
                default_runtime_nvim_dir=NVIM_CONFIG_DIR,
            )
        )
    except RunOutputError as error:
        logging.error(f"{L.E} {error}")
        raise typer.Exit(code=2) from error


@nvim_app.command("info")
def nvim_info_command(nvim_config_dir: str | None = None):
    project_dir = _project_dir()
    """Show sync impact counts for runtime/local nvim configs."""
    logging.info(f"{L.A} Computing neovim sync info")
    _ = nvim_info(
        NvimInfoArgs(
            nvim_config_dir=nvim_config_dir,
            project_dir=project_dir,
            default_runtime_nvim_dir=NVIM_CONFIG_DIR,
        )
    )


@app.command()
def init_docs():
    docs_dir = _docs_dir()
    logging.info(f"{L.A} Setting up sphinx docs structure for {PROJECT_NAME}")
    sphinx_files = [
        docs_dir / "conf.py",
        docs_dir / "index.rst",
        docs_dir / "Makefile",
    ]
    if all([file.exists() for file in sphinx_files]):
        logging.warning(f"{L.E} Sphinx files already exist")
        return
    args = [
        sys.executable,
        "-m",
        "sphinx.cmd.quickstart",
        "--quiet",
        "--no-sep",
        "--project",
        "Prateek's dotfiles",
        "--author",
        "Prateek Raman",
        "--release",
        "1.0",
        str(docs_dir),
    ]
    try:
        run_only(args)
    except RunOutputError as error:
        logging.error(f"{L.E} {error}")
        raise typer.Exit(code=2) from error


if __name__ == "__main__":
    app()
