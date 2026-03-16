# pyright: reportPrivateUsage=false

from collections.abc import Iterator
from pathlib import Path

from dotfiles.nvim import (
    _nvim_copy_from_runtime_to_local,
    _nvim_copy_lua_subdir_manifest,
    _nvim_prune_missing_runtime_local_lua_subdir_entries,
    _nvim_remove_explicit_sync_targets,
    DiskAccessor,
    NvimLuaSubdirManifest,
    NvimPathPair,
    ShellOp,
)

# (operation_name, first_path, second_path_or_none)
type ShellCall = tuple[str, Path, Path | None]
# ((runtime_file_path, local_file_path), files_differ)
type FileDiffMap = dict[tuple[Path, Path], bool]


class SpyShellOp(ShellOp):
    def __init__(self, dry_run: bool) -> None:
        self.dry_run = dry_run
        self.calls: list[ShellCall] = []

    def remove_tree(self, path: Path) -> None:
        self.calls.append(("remove_tree", path, None))

    def copy_tree(self, src: Path, dst: Path) -> None:
        self.calls.append(("copy_tree", src, dst))

    def copy_file(self, src: Path, dst: Path) -> None:
        self.calls.append(("copy_file", src, dst))

    def ensure_parent_dir(self, path: Path) -> None:
        self.calls.append(("ensure_parent_dir", path, None))

    def unlink_file(self, path: Path) -> None:
        self.calls.append(("unlink_file", path, None))


class MockDiskAccessor(DiskAccessor):
    def __init__(
        self,
        *,
        existing_paths: set[Path] | None = None,
        symlink_paths: set[Path] | None = None,
        diff_pairs: FileDiffMap | None = None,
    ) -> None:
        self.existing_paths = existing_paths or set()
        self.symlink_paths = symlink_paths or set()
        self.diff_pairs: FileDiffMap = diff_pairs or {}

    def exists(self, path: Path) -> bool:
        return path in self.existing_paths

    def is_symlink(self, path: Path) -> bool:
        return path in self.symlink_paths

    def walk(
        self, root: Path, followlinks: bool = False
    ) -> Iterator[tuple[Path, list[str], list[str]]]:
        _ = root
        _ = followlinks
        return iter(())

    def files_differ(self, runtime_file_path: Path, local_file_path: Path) -> bool:
        return self.diff_pairs.get((runtime_file_path, local_file_path), False)


def test_remove_explicit_sync_targets_removes_only_non_lua_directories() -> None:
    """Remove explicit sync targets except the Lua root directory.

    GIVEN
    Explicit runtime-to-local dir pairs for lua and after directories.

    WHEN
    Explicit sync targets are removed.

    Then
    Only the non-lua local directory is removed.
    """

    local_nvim_dir = Path("/local/nvim")
    lua_local = local_nvim_dir / "lua"
    after_local = local_nvim_dir / "after"

    runtime_to_local_dir_pairs = [
        NvimPathPair(runtime_path=Path("/runtime/nvim/lua"), local_path=lua_local),
        NvimPathPair(runtime_path=Path("/runtime/nvim/after"), local_path=after_local),
    ]

    shell = SpyShellOp(dry_run=False)
    disk = MockDiskAccessor(existing_paths={after_local})

    _nvim_remove_explicit_sync_targets(
        shell_op=shell,
        local_nvim_dir=local_nvim_dir,
        runtime_to_local_dir_pairs=runtime_to_local_dir_pairs,
        disk_accessor=disk,
    )

    assert shell.calls == [("remove_tree", after_local, None)]


def test_prune_missing_runtime_entries_removes_missing_file_and_dir() -> None:
    """Prune local Lua entries that no longer exist in runtime.

    GIVEN
    Local/runtime Lua manifests with one missing file and one missing dir.

    WHEN
    Missing runtime entries are pruned from local state.

    Then
    The stale local file is unlinked and stale local directory is removed.
    """

    local_nvim_dir = Path("/local/nvim")
    runtime_nvim_dir = Path("/runtime/nvim")

    local_manifest = NvimLuaSubdirManifest(
        dirs={Path("lua"), Path("lua/obsolete")},
        files={Path("lua/user.lua"), Path("lua/plugins/symlink_user-config.tmpl")},
    )
    runtime_manifest = NvimLuaSubdirManifest(
        dirs={Path("lua")},
        files=set(),
    )
    protected = {Path("lua/plugins/symlink_user-config.tmpl")}

    shell = SpyShellOp(dry_run=False)
    disk = MockDiskAccessor(existing_paths={local_nvim_dir / "lua/obsolete"})

    _nvim_prune_missing_runtime_local_lua_subdir_entries(
        shell_op=shell,
        local_nvim_dir=local_nvim_dir,
        runtime_nvim_dir=runtime_nvim_dir,
        log_unchanged_info=False,
        local_lua_subdir_manifest=local_manifest,
        runtime_lua_subdir_manifest=runtime_manifest,
        protected_rel_templates=protected,
        disk_accessor=disk,
    )

    assert shell.calls == [
        ("unlink_file", local_nvim_dir / "lua/user.lua", None),
        ("remove_tree", local_nvim_dir / "lua/obsolete", None),
    ]


def test_prune_missing_runtime_entries_skips_when_runtime_drift_detected() -> None:
    """Skip destructive pruning when runtime drift is detected.

    GIVEN
    Paths that still exist in runtime despite manifest differences.

    WHEN
    Prune logic evaluates missing runtime entries.

    Then
    No delete operations are issued.
    """

    local_nvim_dir = Path("/local/nvim")
    runtime_nvim_dir = Path("/runtime/nvim")

    local_manifest = NvimLuaSubdirManifest(
        dirs={Path("lua"), Path("lua/obsolete")},
        files={Path("lua/user.lua")},
    )
    runtime_manifest = NvimLuaSubdirManifest(
        dirs={Path("lua")},
        files=set(),
    )

    shell = SpyShellOp(dry_run=False)
    disk = MockDiskAccessor(
        existing_paths={
            runtime_nvim_dir / "lua/user.lua",
            runtime_nvim_dir / "lua/obsolete",
            local_nvim_dir / "lua/obsolete",
        }
    )

    _nvim_prune_missing_runtime_local_lua_subdir_entries(
        shell_op=shell,
        local_nvim_dir=local_nvim_dir,
        runtime_nvim_dir=runtime_nvim_dir,
        log_unchanged_info=False,
        local_lua_subdir_manifest=local_manifest,
        runtime_lua_subdir_manifest=runtime_manifest,
        protected_rel_templates=set(),
        disk_accessor=disk,
    )

    assert shell.calls == []


def test_copy_from_runtime_to_local_copies_base_and_changed_top_level_files() -> None:
    """Copy runtime directories and changed top-level files to local.

    GIVEN
    Runtime/local path pairs and file-diff outcomes for top-level files.

    WHEN
    Runtime-to-local copy orchestration runs.

    Then
    It copies existing non-lua dirs and only changed top-level files.
    """

    local_nvim_dir = Path("/local/nvim")
    runtime_nvim_dir = Path("/runtime/nvim")

    runtime_to_local_dir_pairs = [
        NvimPathPair(
            runtime_path=runtime_nvim_dir / "lua",
            local_path=local_nvim_dir / "lua",
        ),
        NvimPathPair(
            runtime_path=runtime_nvim_dir / "after",
            local_path=local_nvim_dir / "after",
        ),
    ]
    runtime_to_local_file_pairs = [
        NvimPathPair(
            runtime_path=runtime_nvim_dir / "init.lua",
            local_path=local_nvim_dir / "init.lua",
        ),
        NvimPathPair(
            runtime_path=runtime_nvim_dir / "lazy-lock.json",
            local_path=local_nvim_dir / "lazy-lock.json",
        ),
        NvimPathPair(
            runtime_path=runtime_nvim_dir / "README.rst",
            local_path=local_nvim_dir / "README.rst",
        ),
    ]

    shell = SpyShellOp(dry_run=False)
    disk = MockDiskAccessor(
        existing_paths={
            runtime_nvim_dir / "after",
            runtime_nvim_dir / "init.lua",
            runtime_nvim_dir / "lazy-lock.json",
            runtime_nvim_dir / "README.rst",
            local_nvim_dir / "lazy-lock.json",
            local_nvim_dir / "README.rst",
        },
        diff_pairs={
            (runtime_nvim_dir / "init.lua", local_nvim_dir / "init.lua"): True,
            (
                runtime_nvim_dir / "lazy-lock.json",
                local_nvim_dir / "lazy-lock.json",
            ): True,
            (runtime_nvim_dir / "README.rst", local_nvim_dir / "README.rst"): False,
        },
    )

    _nvim_copy_from_runtime_to_local(
        shell_op=shell,
        local_nvim_dir=local_nvim_dir,
        runtime_nvim_dir=runtime_nvim_dir,
        log_unchanged_info=False,
        runtime_to_local_dir_pairs=runtime_to_local_dir_pairs,
        runtime_to_local_file_pairs=runtime_to_local_file_pairs,
        disk_accessor=disk,
    )

    assert shell.calls == [
        ("copy_tree", runtime_nvim_dir / "after", local_nvim_dir / "after"),
        ("copy_file", runtime_nvim_dir / "init.lua", local_nvim_dir / "init.lua"),
        (
            "copy_file",
            runtime_nvim_dir / "lazy-lock.json",
            local_nvim_dir / "lazy-lock.json",
        ),
    ]


def test_copy_lua_subdir_manifest_copies_changed_and_ensures_parent_dir() -> None:
    """Copy changed Lua files while ensuring parent directories first.

    GIVEN
    A Lua manifest with changed, unchanged, and protected template files.

    WHEN
    Lua subdir manifest copy logic executes.

    Then
    It ensures parent dirs and copies only changed non-protected files.
    """

    local_nvim_dir = Path("/local/nvim")
    runtime_nvim_dir = Path("/runtime/nvim")

    runtime_manifest = NvimLuaSubdirManifest(
        dirs={Path("lua")},
        files={
            Path("lua/core/options.lua"),
            Path("lua/core/keymaps.lua"),
            Path("lua/core/unchanged.lua"),
            Path("lua/plugins/symlink_os-config.tmpl"),
        },
    )
    protected = {Path("lua/plugins/symlink_os-config.tmpl")}

    shell = SpyShellOp(dry_run=False)
    disk = MockDiskAccessor(
        existing_paths={
            runtime_nvim_dir / "lua/core/options.lua",
            runtime_nvim_dir / "lua/core/keymaps.lua",
            runtime_nvim_dir / "lua/core/unchanged.lua",
            local_nvim_dir / "lua/core/keymaps.lua",
            local_nvim_dir / "lua/core/unchanged.lua",
        },
        diff_pairs={
            (
                runtime_nvim_dir / "lua/core/options.lua",
                local_nvim_dir / "lua/core/options.lua",
            ): True,
            (
                runtime_nvim_dir / "lua/core/keymaps.lua",
                local_nvim_dir / "lua/core/keymaps.lua",
            ): True,
            (
                runtime_nvim_dir / "lua/core/unchanged.lua",
                local_nvim_dir / "lua/core/unchanged.lua",
            ): False,
        },
    )

    _nvim_copy_lua_subdir_manifest(
        shell_op=shell,
        local_nvim_dir=local_nvim_dir,
        runtime_nvim_dir=runtime_nvim_dir,
        log_unchanged_info=False,
        runtime_lua_subdir_manifest=runtime_manifest,
        protected_rel_templates=protected,
        disk_accessor=disk,
    )

    assert shell.calls == [
        ("ensure_parent_dir", local_nvim_dir / "lua/core/options.lua", None),
        (
            "copy_file",
            runtime_nvim_dir / "lua/core/options.lua",
            local_nvim_dir / "lua/core/options.lua",
        ),
        ("ensure_parent_dir", local_nvim_dir / "lua/core/keymaps.lua", None),
        (
            "copy_file",
            runtime_nvim_dir / "lua/core/keymaps.lua",
            local_nvim_dir / "lua/core/keymaps.lua",
        ),
    ]
