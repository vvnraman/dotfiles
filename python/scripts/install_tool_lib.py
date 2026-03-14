import logging
import os
from dataclasses import dataclass
from enum import Enum
from hashlib import sha256
from pathlib import Path

from dotfiles.git import git_branch, is_git_clean
from dotfiles.run_command import run_only
from dotfiles.util import L

MASTER_BRANCH = "master"
DOTFILES_EXE_NAME = "dotfiles"
DOTFILES_DEV_EXE_NAME = "dotfiles-dev"
UV_TOOL_INSTALL_BASE_CMD = ["uv", "tool", "install", ".", "--force", "--refresh"]


class InstallMode(str, Enum):
    STABLE = "stable"
    DIRTY_CUSTOM = "dirty_custom"
    DEV = "dev"


@dataclass(frozen=True)
class ToolInstallArgs:
    project_dir: Path
    dev: bool
    dry_run: bool
    dirty_install_path: str | None = None


@dataclass(frozen=True)
class RepoState:
    branch: str
    clean_worktree: bool


@dataclass(frozen=True)
class InstallPlan:
    mode: InstallMode
    project_dir: Path
    package_dir: Path
    entrypoint_name: str
    editable: bool
    dry_run: bool
    branch: str
    clean_worktree: bool
    entrypoint_bin_dir: Path
    uv_bin_dir: Path | None
    uv_data_dir: Path | None
    uv_env: dict[str, str] | None
    dirs_to_create: tuple[Path, ...]
    dev_wrapper_target: Path | None


class InstallValidationError(RuntimeError):
    pass


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


def _normalize_path(path: Path) -> Path:
    return path.expanduser().resolve()


def _custom_tool_home_dir(install_bin_dir: Path) -> Path:
    # Derive a stable, unique uv tool home from the requested install path so
    # each custom bin path gets its own isolated uv data directory.
    normalized = _normalize_path(install_bin_dir)
    digest = sha256(str(normalized).encode("utf-8")).hexdigest()[:12]
    return Path.home() / ".local" / "share" / f"uv-dotfiles-custom-{digest}"


def _custom_tool_data_dir(install_bin_dir: Path) -> Path:
    return _custom_tool_home_dir(install_bin_dir) / "xdg-data"


def _resolve_repo_state(project_dir: Path) -> RepoState:
    project_dir_str = str(project_dir)
    return RepoState(
        branch=git_branch(project_dir_str),
        clean_worktree=is_git_clean(project_dir_str),
    )


def _build_uv_env(
    uv_bin_dir: Path | None,
    uv_data_dir: Path | None,
) -> dict[str, str] | None:
    if uv_bin_dir is None and uv_data_dir is None:
        return None

    env = os.environ.copy()
    if uv_bin_dir is not None:
        path_parts = [
            str(uv_bin_dir),
            *os.environ.get("PATH", "").split(os.pathsep),
        ]
        env["XDG_BIN_HOME"] = str(uv_bin_dir)
        env["PATH"] = os.pathsep.join(path_parts)
    if uv_data_dir is not None:
        env["XDG_DATA_HOME"] = str(uv_data_dir)
    return env


def _validate_dirty_install_path(dirty_install_path: str | None) -> Path | None:
    if dirty_install_path is None:
        return None

    dirty_install_bin_dir = Path(dirty_install_path).expanduser()
    if _normalize_path(dirty_install_bin_dir) == _normalize_path(_local_bin_dir()):
        raise InstallValidationError(
            f"'--dirty-install-path' cannot be default install path '{_local_bin_dir()}'."
        )
    return dirty_install_bin_dir


def build_install_plan(args: ToolInstallArgs, repo_state: RepoState) -> InstallPlan:
    package_dir = _python_project_dir(args.project_dir)
    dirty_install_bin_dir = _validate_dirty_install_path(args.dirty_install_path)

    if args.dev:
        if dirty_install_bin_dir is not None:
            raise InstallValidationError(
                "'--dirty-install-path' is only supported for non-dev installs."
            )

        mode = InstallMode.DEV
        entrypoint_name = DOTFILES_DEV_EXE_NAME
        editable = True
        entrypoint_bin_dir = _local_bin_dir()
        uv_bin_dir = _dev_tool_bin_dir()
        uv_data_dir = _dev_tool_data_dir()
        dirs_to_create = (uv_data_dir, uv_bin_dir)
        dev_wrapper_target = _dev_tool_executable_path()
    else:
        if dirty_install_bin_dir is None:
            if not repo_state.clean_worktree:
                raise InstallValidationError(
                    f"Refusing install of '{DOTFILES_EXE_NAME}' from dirty worktree."
                )

            if repo_state.branch != MASTER_BRANCH:
                raise InstallValidationError(
                    f"Refusing install of '{DOTFILES_EXE_NAME}' from branch "
                    f"'{repo_state.branch}'. Use branch '{MASTER_BRANCH}'."
                )

            mode = InstallMode.STABLE
            uv_bin_dir = None
            uv_data_dir = None
            dirs_to_create = ()
            entrypoint_bin_dir = _local_bin_dir()
        else:
            mode = InstallMode.DIRTY_CUSTOM
            uv_bin_dir = dirty_install_bin_dir
            uv_data_dir = _custom_tool_data_dir(uv_bin_dir)
            dirs_to_create = (uv_bin_dir, uv_data_dir)
            entrypoint_bin_dir = uv_bin_dir

        entrypoint_name = DOTFILES_EXE_NAME
        editable = False
        dev_wrapper_target = None

    return InstallPlan(
        mode=mode,
        project_dir=args.project_dir,
        package_dir=package_dir,
        entrypoint_name=entrypoint_name,
        editable=editable,
        dry_run=args.dry_run,
        branch=repo_state.branch,
        clean_worktree=repo_state.clean_worktree,
        entrypoint_bin_dir=entrypoint_bin_dir,
        uv_bin_dir=uv_bin_dir,
        uv_data_dir=uv_data_dir,
        uv_env=_build_uv_env(uv_bin_dir, uv_data_dir),
        dirs_to_create=dirs_to_create,
        dev_wrapper_target=dev_wrapper_target,
    )


def _uv_tool_install_command(editable: bool) -> list[str]:
    cmd = [*UV_TOOL_INSTALL_BASE_CMD]
    if editable:
        cmd.append("--editable")
    return cmd


def _run_uv_tool_install(
    package_dir: Path,
    editable: bool,
    dry_run: bool,
    uv_env: dict[str, str] | None,
) -> None:
    cmd = _uv_tool_install_command(editable)
    logging.info(f"{L.B} Running: {' '.join(cmd)}")
    if dry_run:
        return
    run_only(cmd, cwd=package_dir, env=uv_env)


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


def _log_install_start(plan: InstallPlan) -> None:
    if plan.mode is InstallMode.STABLE:
        logging.info(f"{L.A} Installing '{DOTFILES_EXE_NAME}' from clean worktree")
        return

    if plan.mode is InstallMode.DIRTY_CUSTOM:
        logging.info(
            f"{L.B} Skipping clean worktree and branch checks for dirty install path "
            f"'{plan.entrypoint_bin_dir}'."
        )
        if plan.uv_data_dir is not None:
            logging.info(
                f"{L.B} Using isolated uv tool data directory '{plan.uv_data_dir}'"
            )
        logging.info(f"{L.A} Installing '{DOTFILES_EXE_NAME}' using dirty install path")
        return

    logging.info(
        f"{L.A} Installing '{DOTFILES_DEV_EXE_NAME}' from branch "
        f"'{plan.branch}' in editable mode"
    )


def execute_install_plan(plan: InstallPlan) -> None:
    _log_install_start(plan)

    if not plan.dry_run:
        for path in plan.dirs_to_create:
            path.mkdir(parents=True, exist_ok=True)

    _run_uv_tool_install(
        package_dir=plan.package_dir,
        editable=plan.editable,
        dry_run=plan.dry_run,
        uv_env=plan.uv_env,
    )

    if plan.mode is InstallMode.DEV:
        assert plan.dev_wrapper_target is not None
        _install_dev_entrypoint_wrapper(plan.dev_wrapper_target, dry_run=plan.dry_run)

    if plan.dry_run:
        if plan.mode is InstallMode.DEV:
            logging.info(
                f"{L.C} Dry-run complete for '{DOTFILES_DEV_EXE_NAME}' editable entrypoint"
            )
        else:
            logging.info(
                f"{L.C} Dry-run complete for '{DOTFILES_EXE_NAME}' on"
                f" branch '{plan.branch}'"
            )
        return

    if plan.mode is InstallMode.DEV:
        logging.info(f"{L.C} Installed '{DOTFILES_DEV_EXE_NAME}' editable entrypoint")
        return

    logging.info(
        f"{L.C} Installed '{DOTFILES_EXE_NAME}'. Current branch: '{plan.branch}'"
    )


def install_tool_with_mode(args: ToolInstallArgs) -> None:
    repo_state = _resolve_repo_state(args.project_dir)
    plan = build_install_plan(args, repo_state)
    execute_install_plan(plan)
