from pathlib import Path

from dotfiles.paths import (
    CHEZMOI_DOTFILES_PATH_OVERRIDE,
    PROJECT_MARKERS,
    ConfigLookupResult,
    SourceRootResolutionError,
    SourceRootResolutionIO,
    resolve_project_dir_with_io,
)
from dotfiles.run_command import ProcessResult


class FakeSourceRootResolutionIO(SourceRootResolutionIO):
    """Deterministic IO fake for source-root resolution tests.

    Each constructor input controls one external dependency used by the resolver:
    path checks, marker detection, config lookup, chezmoi command output, and env.
    """

    def __init__(
        self,
        *,
        expected_config_path: Path,
        existing_paths: set[Path],
        marker_roots: set[Path],
        config_lookup_result: ConfigLookupResult,
        chezmoi_result: ProcessResult,
        env_values: dict[str, str],
    ) -> None:
        # Paths considered to exist on the fake filesystem.
        self._expected_config_path = expected_config_path
        self._existing_paths = existing_paths
        # Paths treated as valid git/source roots (contain project markers).
        self._marker_roots = marker_roots
        # Result returned when reading [paths].git_root from config.
        self._config_lookup_result = config_lookup_result
        # Output returned for "chezmoi source-path" command simulation.
        self._chezmoi_result = chezmoi_result
        # Environment variable values used by fallback resolution.
        self._env_values = env_values

    def path_exists(self, path: Path) -> bool:
        return path.expanduser() in self._existing_paths

    def resolve_path(self, path: Path) -> Path:
        return path.expanduser()

    def has_project_marker(self, path: Path, markers: tuple[str, ...]) -> bool:
        assert markers == PROJECT_MARKERS
        return path in self._marker_roots

    def lookup_config_value(
        self,
        config_path: Path,
        section: str,
        key: str,
    ) -> ConfigLookupResult:
        assert config_path == self._expected_config_path
        assert section == "paths"
        assert key == "git_root"
        return self._config_lookup_result

    def run_chezmoi_source_path(self) -> ProcessResult:
        return self._chezmoi_result

    def getenv(self, key: str) -> str | None:
        return self._env_values.get(key)


def test_resolve_project_dir_with_io_prefers_config_source_root() -> None:
    """Resolve from config-provided source root when present.

    GIVEN
    A config value that points to an existing marker root.

    WHEN
    Source-root resolution runs without a CLI override.

    Then
    The resolver returns the config-provided root.
    """

    io = FakeSourceRootResolutionIO(
        expected_config_path=Path("/cfg/dotfiles-config.ini"),
        existing_paths={Path("/repo")},
        marker_roots={Path("/repo")},
        config_lookup_result=ConfigLookupResult(value="/repo"),
        chezmoi_result=ProcessResult(returncode=1, stdout="", stderr="missing"),
        env_values={},
    )

    result = resolve_project_dir_with_io(
        io=io,
        source_root_override=None,
        config_path=Path("/cfg/dotfiles-config.ini"),
    )

    assert result == Path("/repo")


def test_resolve_project_dir_with_io_stops_on_invalid_cli_source_root() -> None:
    """Stop resolution when explicit CLI source-root is invalid.

    GIVEN
    A CLI --source-root path that does not exist.

    WHEN
    Resolution starts with that explicit override.

    Then
    The resolver raises and records only CLI failure steps.
    """

    io = FakeSourceRootResolutionIO(
        expected_config_path=Path("/cfg/dotfiles-config.ini"),
        existing_paths={Path("/repo")},
        marker_roots={Path("/repo")},
        config_lookup_result=ConfigLookupResult(value="/repo"),
        chezmoi_result=ProcessResult(returncode=0, stdout="/repo", stderr=""),
        env_values={CHEZMOI_DOTFILES_PATH_OVERRIDE: "/repo"},
    )

    try:
        _ = resolve_project_dir_with_io(
            io=io,
            source_root_override="/does-not-exist",
            config_path=Path("/cfg/dotfiles-config.ini"),
        )
        raise AssertionError("Expected SourceRootResolutionError")
    except SourceRootResolutionError as error:
        assert "cli --source-root: '/does-not-exist' does not exist" in error.attempts
        assert (
            "cli --source-root: explicit override provided but invalid; stopping"
            in error.attempts
        )
        assert not any(attempt.startswith("config file:") for attempt in error.attempts)


def test_resolve_project_dir_with_io_falls_back_to_chezmoi_source_path() -> None:
    """Use chezmoi source-path fallback and walk to project root.

    GIVEN
    No CLI override and no config git_root value.

    WHEN
    chezmoi source-path returns a nested home source directory.

    Then
    Resolution walks up and returns the repository root with markers.
    """

    io = FakeSourceRootResolutionIO(
        expected_config_path=Path("/cfg/dotfiles-config.ini"),
        existing_paths={
            Path("/home/user/.local/share/chezmoi/home"),
            Path("/home/user/.local/share/chezmoi"),
        },
        marker_roots={Path("/home/user/.local/share/chezmoi")},
        config_lookup_result=ConfigLookupResult(value=None),
        chezmoi_result=ProcessResult(
            returncode=0,
            stdout="/home/user/.local/share/chezmoi/home\n",
            stderr="",
        ),
        env_values={},
    )

    result = resolve_project_dir_with_io(
        io=io,
        source_root_override=None,
        config_path=Path("/cfg/dotfiles-config.ini"),
    )

    assert result == Path("/home/user/.local/share/chezmoi")


def test_resolve_project_dir_prefers_runtime_package_root_before_config() -> None:
    """Prefer repo root discovered from runtime package path.

    GIVEN
    A runtime package path inside a checkout and a conflicting config git_root.

    WHEN
    Resolution runs without CLI override.

    Then
    The resolver returns the checkout root from runtime package ancestry.
    """

    config_path = Path("/worktrees/master/python/src/dotfiles/dotfiles-config.ini")
    io = FakeSourceRootResolutionIO(
        expected_config_path=config_path,
        existing_paths={
            Path("/worktrees/master/python/src/dotfiles"),
            Path("/canonical/chezmoi"),
        },
        marker_roots={Path("/worktrees/master")},
        config_lookup_result=ConfigLookupResult(value="/canonical/chezmoi"),
        chezmoi_result=ProcessResult(returncode=1, stdout="", stderr="missing"),
        env_values={},
    )

    result = resolve_project_dir_with_io(
        io=io,
        source_root_override=None,
        config_path=config_path,
    )

    assert result == Path("/worktrees/master")


def test_resolve_project_dir_with_io_uses_config_when_runtime_path_not_repo() -> None:
    """Fallback to config value when runtime package path is not a repo.

    GIVEN
    A package path outside a checkout and a valid config git_root.

    WHEN
    Resolution runs without CLI override.

    Then
    The resolver returns the configured git_root.
    """

    config_path = Path("/site-packages/dotfiles/dotfiles-config.ini")
    io = FakeSourceRootResolutionIO(
        expected_config_path=config_path,
        existing_paths={Path("/site-packages/dotfiles"), Path("/canonical/chezmoi")},
        marker_roots={Path("/canonical/chezmoi")},
        config_lookup_result=ConfigLookupResult(value="/canonical/chezmoi"),
        chezmoi_result=ProcessResult(returncode=1, stdout="", stderr="missing"),
        env_values={},
    )

    result = resolve_project_dir_with_io(
        io=io,
        source_root_override=None,
        config_path=config_path,
    )

    assert result == Path("/canonical/chezmoi")
