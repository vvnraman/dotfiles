import logging
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path

from dotfiles.git import git_branch, is_git_clean
from dotfiles.util import L

MASTER_BRANCH = "master"
DOTFILES_EXE_NAME = "dotfiles"
DOTFILES_DEV_EXE_NAME = "dotfiles-dev"


@dataclass(frozen=True)
class ToolInstallArgs:
    project_dir: Path
    dev: bool
    dry_run: bool


def _python_project_dir(project_dir: Path) -> Path:
    return project_dir / "python"


def _local_bin_dir() -> Path:
    return Path.home() / ".local" / "bin"


def _dotfiles_dev_executable_path() -> Path:
    return _local_bin_dir() / DOTFILES_DEV_EXE_NAME


def _dev_tool_home_dir() -> Path:
    return Path.home() / ".local" / "share" / "uv-dotfiles-dev"


def _dev_tool_data_dir() -> Path:
    return _dev_tool_home_dir() / "xdg-data"


def _dev_tool_bin_dir() -> Path:
    return _dev_tool_home_dir() / "xdg-bin"


def _dev_tool_executable_path() -> Path:
    return _dev_tool_bin_dir() / DOTFILES_EXE_NAME


def _run_uv_tool_install(
    package_dir: Path,
    editable: bool,
    dry_run: bool,
    env_overrides: dict[str, str] | None = None,
) -> None:
    cmd = ["uv", "tool", "install", ".", "--force"]
    if editable:
        cmd.append("--editable")
    logging.info(f"{L.B} Running: {' '.join(cmd)}")
    if dry_run:
        return

    env = os.environ.copy()
    if env_overrides is not None:
        env.update(env_overrides)
    _ = subprocess.run(cmd, cwd=package_dir, check=True, env=env)


def _install_dev_entrypoint_wrapper(dev_tool_exe_path: Path, dry_run: bool) -> None:
    bin_dir = _local_bin_dir()
    if not dry_run:
        bin_dir.mkdir(parents=True, exist_ok=True)

    dotfiles_dev_path = _dotfiles_dev_executable_path()

    script = "\n".join(
        [
            "#!/usr/bin/env sh",
            f'exec "{dev_tool_exe_path}" "$@"',
            "",
        ]
    )

    if dry_run:
        logging.info(f"{L.B} Would write dev wrapper to '{dotfiles_dev_path}'")
        return

    _ = dotfiles_dev_path.write_text(script, encoding="utf-8")
    dotfiles_dev_path.chmod(0o755)
    logging.info(f"{L.B} Installed dev entrypoint at '{dotfiles_dev_path}'")


def install_tool_with_mode(args: ToolInstallArgs) -> None:
    project_dir_str = str(args.project_dir)
    current_branch = git_branch(project_dir_str)
    clean_worktree = is_git_clean(project_dir_str)
    package_dir = _python_project_dir(args.project_dir)

    if not args.dev:
        if not clean_worktree:
            logging.warning(
                f"{L.E} Refusing install of '{DOTFILES_EXE_NAME}' from dirty worktree."
            )
            return

        if current_branch != MASTER_BRANCH:
            logging.warning(
                f"{L.E} Refusing install of '{DOTFILES_EXE_NAME}' from branch"
                f" '{current_branch}'. Use branch '{MASTER_BRANCH}'."
            )
            return

        logging.info(f"{L.A} Installing '{DOTFILES_EXE_NAME}' from clean worktree")
        _run_uv_tool_install(
            package_dir=package_dir,
            editable=False,
            dry_run=args.dry_run,
        )
        if args.dry_run:
            logging.info(
                f"{L.C} Dry-run complete for '{DOTFILES_EXE_NAME}' on"
                f" branch '{current_branch}'"
            )
        else:
            logging.info(
                f"{L.C} Installed '{DOTFILES_EXE_NAME}'. Current branch: '{current_branch}'"
            )
        return

    logging.info(
        f"{L.A} Installing '{DOTFILES_DEV_EXE_NAME}' from branch "
        f"'{current_branch}' in editable mode"
    )
    dev_data_dir = _dev_tool_data_dir()
    dev_bin_dir = _dev_tool_bin_dir()
    if not args.dry_run:
        dev_data_dir.mkdir(parents=True, exist_ok=True)
        dev_bin_dir.mkdir(parents=True, exist_ok=True)
    # Use a dedicated XDG tool home so editable dev installs never replace
    # the default uv-managed dotfiles tool or its global bin symlinks.
    path_parts = [str(dev_bin_dir), *os.environ.get("PATH", "").split(os.pathsep)]
    dev_env = {
        "XDG_DATA_HOME": str(dev_data_dir),
        "XDG_BIN_HOME": str(dev_bin_dir),
        "PATH": os.pathsep.join(path_parts),
    }
    _run_uv_tool_install(
        package_dir=package_dir,
        editable=True,
        dry_run=args.dry_run,
        env_overrides=dev_env,
    )
    _install_dev_entrypoint_wrapper(_dev_tool_executable_path(), dry_run=args.dry_run)
    if args.dry_run:
        logging.info(
            f"{L.C} Dry-run complete for '{DOTFILES_DEV_EXE_NAME}' editable entrypoint"
        )
    else:
        logging.info(f"{L.C} Installed '{DOTFILES_DEV_EXE_NAME}' editable entrypoint")
