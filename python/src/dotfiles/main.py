import logging
import subprocess
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
from dotfiles.paths import resolve_project_dir
from dotfiles.publish import PublishArgs, publish_with_config
from dotfiles.tool_install import ToolInstallArgs, install_tool_with_mode
from dotfiles.util import L

PROJECT_NAME = "dotfiles"

PROJECT_DIR = resolve_project_dir(Path.cwd(), Path(__file__))
DOCS_DIR = PROJECT_DIR / "docs"
BUILD_DIR = DOCS_DIR / "_build"
HTML_DIR = BUILD_DIR / "html"
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


def _configure_app_logging() -> None:
    configure_logging()


app = typer.Typer(callback=_configure_app_logging)
nvim_app = typer.Typer(help="Neovim config sync and info commands")
app.add_typer(nvim_app, name="nvim")


@app.command()
def info():
    logging.info(f"{L.A} Project        = {PROJECT_NAME}")
    logging.info(f"{L.B} Project dir    = {PROJECT_DIR}")
    logging.info(f"{L.B} Docs dir       = {DOCS_DIR}")
    logging.info(f"{L.B} Build dir      = {BUILD_DIR}")
    logging.info(f"{L.B} HTML dir       = {HTML_DIR}")


@app.command()
def docs():
    logging.info(f"{L.A} Building docs for {PROJECT_NAME}")
    args = ["sphinx-build", "--builder", "html", str(DOCS_DIR), str(BUILD_DIR)]
    _ = subprocess.run(args)


@app.command()
def live():
    logging.info(f"{L.A} Building livedocs for {PROJECT_NAME}")
    args = [
        "sphinx-autobuild",
        "--port",
        "0",
        "--open-browser",
        str(DOCS_DIR),
        str(HTML_DIR),
    ]
    _ = subprocess.run(args)


@app.command()
def clean():
    logging.info(f"{L.A} Cleaning docs for {PROJECT_NAME}")
    args = ["sphinx-build", "-M", "clean", str(DOCS_DIR), str(BUILD_DIR)]
    _ = subprocess.run(args)


@app.command()
def publish(
    dry_run: bool = True,
    override_branch: str | None = None,
    remote_name: str | None = None,
    dotfiles_repo: str | None = None,
    github_url: str | None = None,
    publish_host: str | None = None,
) -> None:
    logging.info(f"{L.A} Publishing docs for {PROJECT_NAME}")
    publish_with_config(
        PublishArgs(
            project_dir=PROJECT_DIR,
            dry_run=dry_run,
            override_branch=override_branch,
            remote_name=remote_name,
            dotfiles_repo=dotfiles_repo,
            github_url=github_url,
            publish_host=publish_host,
        )
    )


@app.command("install-tool")
def install_tool(
    dev: bool = False,
    dry_run: Annotated[
        bool | None,
        typer.Option("--dry-run/--no-dry-run"),
    ] = None,
) -> None:
    logging.info(f"{L.A} Installing uv tool entrypoints for {PROJECT_NAME}")
    resolved_dry_run = dry_run if dry_run is not None else (not dev)
    install_tool_with_mode(
        ToolInstallArgs(
            project_dir=PROJECT_DIR,
            dev=dev,
            dry_run=resolved_dry_run,
        )
    )


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
    """Sync runtime nvim config into local chezmoi state."""
    logging.info(f"{L.A} Syncing with neovim config")
    nvim_sync_with_mimic(
        NvimSyncWithMimicArgs(
            dry_run=dry_run,
            mimic=mimic,
            nvim_config_dir=nvim_config_dir,
            override_branch_name=override_branch_name,
            log_unchanged_info=log_unchanged_info,
            project_dir=PROJECT_DIR,
            default_runtime_nvim_dir=NVIM_CONFIG_DIR,
        )
    )


@nvim_app.command("info")
def nvim_info_command(nvim_config_dir: str | None = None):
    """Show sync impact counts for runtime/local nvim configs."""
    logging.info(f"{L.A} Computing neovim sync info")
    _ = nvim_info(
        NvimInfoArgs(
            nvim_config_dir=nvim_config_dir,
            project_dir=PROJECT_DIR,
            default_runtime_nvim_dir=NVIM_CONFIG_DIR,
        )
    )


@app.command()
def init_docs():
    logging.info(f"{L.A} Setting up sphinx docs structure for {PROJECT_NAME}")
    sphinx_files = [
        DOCS_DIR / "conf.py",
        DOCS_DIR / "index.rst",
        DOCS_DIR / "Makefile",
    ]
    if all([file.exists() for file in sphinx_files]):
        logging.warning(f"{L.E} Sphinx files already exist")
        return
    args = [
        "sphinx-quickstart",
        "--quiet",
        "--no-sep",
        "--project",
        "Prateek's dotfiles",
        "--author",
        "Prateek Raman",
        "--release",
        "1.0",
        str(DOCS_DIR),
    ]
    _ = subprocess.run(args)


if __name__ == "__main__":
    app()
