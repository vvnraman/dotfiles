import configparser
import os
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path
from typing import Callable, NoReturn, Protocol

from dotfiles.run_command import ProcessResult, run_capture

PROJECT_MARKERS = (".chezmoiroot", ".git")
CONFIG_SECTION_PATHS = "paths"
CONFIG_KEY_GIT_ROOT = "git_root"
CHEZMOI_DOTFILES_PATH_OVERRIDE = "CHEZMOI_DOTFILES_PATH_OVERRIDE"

_source_root_override: str | None = None


@dataclass(frozen=True)
class ConfigLookupResult:
    value: str | None
    file_missing: bool = False
    error: str | None = None


class SourceRootResolutionIO(Protocol):
    def path_exists(self, path: Path) -> bool: ...

    def resolve_path(self, path: Path) -> Path: ...

    def has_project_marker(self, path: Path, markers: tuple[str, ...]) -> bool: ...

    def lookup_config_value(
        self,
        config_path: Path,
        section: str,
        key: str,
    ) -> ConfigLookupResult: ...

    def run_chezmoi_source_path(self) -> ProcessResult: ...

    def getenv(self, key: str) -> str | None: ...


class RealSourceRootResolutionIO(SourceRootResolutionIO):
    def path_exists(self, path: Path) -> bool:
        return path.exists()

    def resolve_path(self, path: Path) -> Path:
        return path.expanduser().resolve()

    def has_project_marker(self, path: Path, markers: tuple[str, ...]) -> bool:
        return any((path / marker).exists() for marker in markers)

    def lookup_config_value(
        self,
        config_path: Path,
        section: str,
        key: str,
    ) -> ConfigLookupResult:
        if not config_path.exists():
            return ConfigLookupResult(value=None, file_missing=True)

        config = configparser.ConfigParser()
        try:
            _ = config.read(config_path)
        except configparser.Error as error:
            return ConfigLookupResult(value=None, error=str(error))

        value = config.get(section, key, fallback="").strip()
        if not value:
            return ConfigLookupResult(value=None)

        return ConfigLookupResult(value=value)

    def run_chezmoi_source_path(self) -> ProcessResult:
        return run_capture(["chezmoi", "source-path"])

    def getenv(self, key: str) -> str | None:
        return os.getenv(key)


REAL_SOURCE_ROOT_IO = RealSourceRootResolutionIO()


@dataclass
class DiscoveryTrace:
    """Collects and emits source-root resolution steps.

    Every strategy attempt appends a human-readable message to ``attempts``.
    When a step logger is provided (for ``--show-source-discovery``), the same
    message is emitted immediately so users can see resolution progress in order.
    """

    step_logger: Callable[[str], None] | None = None
    attempts: list[str] = field(default_factory=list)

    def add(self, message: str) -> None:
        self.attempts.append(message)
        if self.step_logger is not None:
            self.step_logger(message)

    def fail(self) -> NoReturn:
        raise SourceRootResolutionError(self.attempts)


@dataclass(frozen=True)
class ResolverContext:
    """Runtime context for one source-root resolution attempt.

    The resolver passes this object through each strategy so all logic uses the
    same IO adapter, config path, CLI override, and shared ``DiscoveryTrace``.
    This keeps resolution flow deterministic and ensures the final failure
    includes the full ordered path of attempted strategies.
    """

    io: SourceRootResolutionIO
    config_path: Path
    source_root_override: str | None
    trace: DiscoveryTrace


class SourceRootResolutionError(RuntimeError):
    def __init__(self, attempts: list[str]):
        self.attempts = attempts
        attempted = "\n- ".join(attempts)
        message = (
            f"Could not resolve dotfiles git root. Attempted strategies:\n- {attempted}"
        )
        super().__init__(message)


def _find_project_root(start_path: Path, io: SourceRootResolutionIO) -> Path | None:
    candidates = [start_path, *start_path.parents]
    for candidate in candidates:
        if io.has_project_marker(candidate, PROJECT_MARKERS):
            return candidate
    return None


def _resolve_direct_project_root(
    value: str,
    strategy: str,
    ctx: ResolverContext,
) -> Path | None:
    candidate = Path(value).expanduser()
    if not ctx.io.path_exists(candidate):
        ctx.trace.add(f"{strategy}: '{candidate}' does not exist")
        return None

    resolved = ctx.io.resolve_path(candidate)
    if not ctx.io.has_project_marker(resolved, PROJECT_MARKERS):
        ctx.trace.add(
            f"{strategy}: '{resolved}' is not a dotfiles git root "
            "(missing .chezmoiroot/.git)",
        )
        return None

    ctx.trace.add(f"{strategy}: success -> '{resolved}'")
    return resolved


def _config_git_root(ctx: ResolverContext) -> str | None:
    config_result = ctx.io.lookup_config_value(
        ctx.config_path,
        CONFIG_SECTION_PATHS,
        CONFIG_KEY_GIT_ROOT,
    )
    if config_result.file_missing:
        ctx.trace.add(f"config file '{ctx.config_path}': not found")
        return None
    if config_result.error is not None:
        ctx.trace.add(
            f"config file '{ctx.config_path}': failed reading: {config_result.error}"
        )
        return None

    config_value = config_result.value
    if not config_value:
        ctx.trace.add(
            f"config file '{ctx.config_path}': [{CONFIG_SECTION_PATHS}] "
            f"{CONFIG_KEY_GIT_ROOT} not set"
        )
        return None

    ctx.trace.add(
        f"config file '{ctx.config_path}': [{CONFIG_SECTION_PATHS}] "
        f"{CONFIG_KEY_GIT_ROOT} -> '{config_value}'",
    )

    return config_value


def _resolve_from_chezmoi_source_path(ctx: ResolverContext) -> Path | None:
    ctx.trace.add("chezmoi source-path: running 'chezmoi source-path'")
    command_result = ctx.io.run_chezmoi_source_path()
    if command_result.returncode != 0:
        stderr = command_result.stderr.strip()
        ctx.trace.add(
            "chezmoi source-path: failed"
            + (f" ({stderr})" if stderr else " (non-zero exit)"),
        )
        return None

    source_path_raw = command_result.stdout.strip()
    if not source_path_raw:
        ctx.trace.add("chezmoi source-path: returned empty output")
        return None

    ctx.trace.add(f"chezmoi source-path: got '{source_path_raw}'")

    source_path = Path(source_path_raw).expanduser()
    if not ctx.io.path_exists(source_path):
        ctx.trace.add(f"chezmoi source-path: '{source_path}' does not exist")
        return None

    resolved_source_path = ctx.io.resolve_path(source_path)
    resolved = _find_project_root(resolved_source_path, ctx.io)
    if resolved is None:
        ctx.trace.add(
            "chezmoi source-path: could not walk to project root from "
            f"'{resolved_source_path}'",
        )
        return None

    ctx.trace.add(f"chezmoi source-path: success -> '{resolved}'")
    return resolved


def _resolve_from_runtime_package_path(ctx: ResolverContext) -> Path | None:
    package_dir = ctx.config_path.parent
    if not ctx.io.path_exists(package_dir):
        ctx.trace.add(f"runtime package path: '{package_dir}' does not exist")
        return None

    resolved_package_dir = ctx.io.resolve_path(package_dir)
    ctx.trace.add(f"runtime package path: start at '{resolved_package_dir}'")
    resolved = _find_project_root(resolved_package_dir, ctx.io)
    if resolved is None:
        ctx.trace.add(
            "runtime package path: could not walk to project root from "
            f"'{resolved_package_dir}'",
        )
        return None

    ctx.trace.add(f"runtime package path: success -> '{resolved}'")
    return resolved


def _resolve_project_dir_with_context(ctx: ResolverContext) -> Path:
    if ctx.source_root_override is not None:
        project_root = _resolve_direct_project_root(
            ctx.source_root_override,
            "cli --source-root",
            ctx,
        )
        if project_root is not None:
            return project_root
        ctx.trace.add(
            "cli --source-root: explicit override provided but invalid; stopping",
        )
        ctx.trace.fail()
    else:
        ctx.trace.add("cli --source-root: not provided")

    project_root = _resolve_from_runtime_package_path(ctx)
    if project_root is not None:
        return project_root

    config_git_root = _config_git_root(ctx)
    if config_git_root is not None:
        project_root = _resolve_direct_project_root(
            config_git_root,
            f"config [{CONFIG_SECTION_PATHS}] {CONFIG_KEY_GIT_ROOT}",
            ctx,
        )
        if project_root is not None:
            return project_root

    project_root = _resolve_from_chezmoi_source_path(ctx)
    if project_root is not None:
        return project_root

    env_override = ctx.io.getenv(CHEZMOI_DOTFILES_PATH_OVERRIDE)
    if env_override:
        ctx.trace.add(f"env {CHEZMOI_DOTFILES_PATH_OVERRIDE}: value provided")
        project_root = _resolve_direct_project_root(
            env_override,
            f"env {CHEZMOI_DOTFILES_PATH_OVERRIDE}",
            ctx,
        )
        if project_root is not None:
            return project_root
    else:
        ctx.trace.add(f"env {CHEZMOI_DOTFILES_PATH_OVERRIDE}: not provided")

    ctx.trace.fail()


def package_config_path() -> Path:
    return Path(__file__).resolve().parent / "dotfiles-config.ini"


def set_source_root_override(path: str | None) -> None:
    global _source_root_override
    _source_root_override = path
    resolve_project_dir.cache_clear()


def resolve_project_dir_with_io(
    io: SourceRootResolutionIO,
    source_root_override: str | None,
    step_logger: Callable[[str], None] | None = None,
    config_path: Path | None = None,
) -> Path:
    resolved_config_path = config_path or package_config_path()
    context = ResolverContext(
        io=io,
        config_path=resolved_config_path,
        source_root_override=source_root_override,
        trace=DiscoveryTrace(step_logger=step_logger),
    )
    return _resolve_project_dir_with_context(context)


def show_project_dir_discovery(step_logger: Callable[[str], None]) -> Path:
    return resolve_project_dir_with_io(
        io=REAL_SOURCE_ROOT_IO,
        source_root_override=_source_root_override,
        step_logger=step_logger,
    )


@lru_cache(maxsize=1)
def resolve_project_dir() -> Path:
    return resolve_project_dir_with_io(
        io=REAL_SOURCE_ROOT_IO,
        source_root_override=_source_root_override,
    )
