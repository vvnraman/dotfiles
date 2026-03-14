import filecmp
import logging
import os
import shutil
import tempfile
from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path
from typing import NamedTuple, Protocol

from dotfiles.git import git_branch, is_git_clean
from dotfiles.util import L


class NvimPathPair(NamedTuple):
    """Represents a path mapping from runtime config to local destination."""

    runtime_path: Path
    local_path: Path


class NvimLuaSubdirManifest(NamedTuple):
    """Manifest for `lua/` sub-directories and files discovered from a Neovim tree."""

    dirs: set[Path]
    files: set[Path]


class NvimSyncInfoCounts(NamedTuple):
    """Counts describing how sync will affect local nvim config."""

    runtime_total_dirs: int
    runtime_total_files: int
    local_total_dirs: int
    local_total_files: int
    remove_dirs: int
    remove_files: int
    add_dirs: int
    add_files: int
    update_dirs: int
    update_files: int


class NvimSubdirManifest(NamedTuple):
    """Manifest for one managed non-`lua/` base subdirectory."""

    exists: bool
    dirs: set[Path]
    files: set[Path]


class NvimSyncPlan(NamedTuple):
    """All precomputed inputs needed by sync and info flows."""

    protected_rel_templates: set[Path]
    runtime_to_local_dir_pairs: list[NvimPathPair]
    runtime_to_local_file_pairs: list[NvimPathPair]
    runtime_lua_subdir_manifest: NvimLuaSubdirManifest
    local_lua_subdir_manifest: NvimLuaSubdirManifest
    runtime_base_manifests: dict[Path, NvimSubdirManifest]
    local_base_manifests: dict[Path, NvimSubdirManifest]


class ShellOp(Protocol):
    """Filesystem mutation interface for real and dry runs."""

    dry_run: bool

    def remove_tree(self, path: Path) -> None: ...

    def copy_tree(self, src: Path, dst: Path) -> None: ...

    def copy_file(self, src: Path, dst: Path) -> None: ...

    def ensure_parent_dir(self, path: Path) -> None: ...

    def unlink_file(self, path: Path) -> None: ...


class DiskAccessor(Protocol):
    """Filesystem read interface for real and mocked disk state."""

    def exists(self, path: Path) -> bool: ...

    def is_symlink(self, path: Path) -> bool: ...

    def walk(
        self, root: Path, followlinks: bool = False
    ) -> Iterator[tuple[Path, list[str], list[str]]]: ...

    def files_differ(self, runtime_file_path: Path, local_file_path: Path) -> bool: ...


class RealDiskAccessor(DiskAccessor):
    def exists(self, path: Path) -> bool:
        return path.exists()

    def is_symlink(self, path: Path) -> bool:
        return path.is_symlink()

    def walk(
        self, root: Path, followlinks: bool = False
    ) -> Iterator[tuple[Path, list[str], list[str]]]:
        for current_root, dirnames, filenames in os.walk(root, followlinks=followlinks):
            yield Path(current_root), dirnames, filenames

    def files_differ(self, runtime_file_path: Path, local_file_path: Path) -> bool:
        return not filecmp.cmp(runtime_file_path, local_file_path, shallow=False)


def _resolve_disk_accessor(disk_accessor: DiskAccessor | None) -> DiskAccessor:
    return disk_accessor or RealDiskAccessor()


@dataclass(frozen=True)
class NvimSyncWithMimicArgs:
    dry_run: bool
    mimic: bool
    nvim_config_dir: str | None
    override_branch_name: str | None
    log_unchanged_info: bool
    project_dir: Path
    default_runtime_nvim_dir: Path
    disk_accessor: DiskAccessor | None = None


@dataclass(frozen=True)
class NvimInfoArgs:
    nvim_config_dir: str | None
    project_dir: Path
    default_runtime_nvim_dir: Path
    disk_accessor: DiskAccessor | None = None
    local_nvim_dir_override: Path | None = None
    runtime_nvim_dir_override: Path | None = None


class RealShellOp(ShellOp):
    dry_run = False

    def remove_tree(self, path: Path) -> None:
        shutil.rmtree(path)

    def copy_tree(self, src: Path, dst: Path) -> None:
        _ = shutil.copytree(src, dst, dirs_exist_ok=True)

    def copy_file(self, src: Path, dst: Path) -> None:
        _ = shutil.copy2(src, dst)

    def ensure_parent_dir(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)

    def unlink_file(self, path: Path) -> None:
        path.unlink(missing_ok=True)


class DryShellOp(ShellOp):
    dry_run = True

    def remove_tree(self, path: Path) -> None:
        return

    def copy_tree(self, src: Path, dst: Path) -> None:
        return

    def copy_file(self, src: Path, dst: Path) -> None:
        return

    def ensure_parent_dir(self, path: Path) -> None:
        return

    def unlink_file(self, path: Path) -> None:
        return


def nvim_build_path_pairs(
    rel_paths: list[Path], runtime_nvim_dir: Path, local_nvim_dir: Path
) -> list[NvimPathPair]:
    """Build mapped runtime/local path pairs for each provided relative path."""
    return [
        NvimPathPair(
            runtime_path=runtime_nvim_dir / rel_path,
            local_path=local_nvim_dir / rel_path,
        )
        for rel_path in rel_paths
    ]


def nvim_build_lua_subdir_manifest(
    nvim_dir: Path,
    log_details: bool = True,
    disk_accessor: DiskAccessor | None = None,
) -> NvimLuaSubdirManifest:
    """Build a manifest of Lua subdir directories and files, excluding symlinks."""
    disk = _resolve_disk_accessor(disk_accessor)
    lua_dir_rel = Path("lua")
    lua_dir = nvim_dir / lua_dir_rel
    lua_manifest_dirs: set[Path] = {lua_dir_rel}
    lua_manifest_files: set[Path] = set()

    if log_details:
        logging.info(f"{L.B} Building Lua subdir manifest from {lua_dir}")

    for root_path, dirnames, filenames in disk.walk(lua_dir, followlinks=False):
        for dirname in dirnames:
            runtime_dir_path = root_path / dirname
            if disk.is_symlink(runtime_dir_path):
                if log_details:
                    logging.info(f"{L.C} Skipping symlink dir {runtime_dir_path}")
                continue

            lua_manifest_dirs.add(runtime_dir_path.relative_to(nvim_dir))

        for filename in filenames:
            runtime_file_path = root_path / filename
            if disk.is_symlink(runtime_file_path):
                if log_details:
                    logging.info(f"{L.C} Skipping symlink file {runtime_file_path}")
                continue

            lua_manifest_files.add(runtime_file_path.relative_to(nvim_dir))

    return NvimLuaSubdirManifest(dirs=lua_manifest_dirs, files=lua_manifest_files)


def nvim_build_subdir_manifest(
    subdir_path: Path, disk_accessor: DiskAccessor | None = None
) -> NvimSubdirManifest:
    """Build a manifest for one managed base subdir, skipping symlinks."""
    disk = _resolve_disk_accessor(disk_accessor)
    if not disk.exists(subdir_path):
        return NvimSubdirManifest(exists=False, dirs=set(), files=set())

    subdir_dirs: set[Path] = set()
    subdir_files: set[Path] = set()

    for root_path, dirnames, filenames in disk.walk(subdir_path, followlinks=False):
        rel_root = root_path.relative_to(subdir_path)

        filtered_dirnames: list[str] = []
        for dirname in dirnames:
            dir_path = root_path / dirname
            if disk.is_symlink(dir_path):
                continue
            filtered_dirnames.append(dirname)
            subdir_dirs.add(rel_root / dirname)
        dirnames[:] = filtered_dirnames

        for filename in filenames:
            file_path = root_path / filename
            if disk.is_symlink(file_path):
                continue
            subdir_files.add(rel_root / filename)

    return NvimSubdirManifest(exists=True, dirs=subdir_dirs, files=subdir_files)


def nvim_build_sync_plan(
    local_nvim_dir: Path,
    runtime_nvim_dir: Path,
    log_details: bool = True,
    disk_accessor: DiskAccessor | None = None,
) -> NvimSyncPlan:
    """Build shared sync inputs for both sync and info flows."""
    disk = _resolve_disk_accessor(disk_accessor)
    protected_rel_templates: set[Path] = {
        Path("lua") / "plugins" / template
        for template in ("symlink_os-config.tmpl", "symlink_user-config.tmpl")
    }

    nvim_cfg_base_dirs: list[Path] = [Path("lua"), Path("after")]
    nvim_cfg_toplevel_files: list[Path] = [
        Path("init.lua"),
        Path("lazy-lock.json"),
        Path("README.rst"),
        Path("stylua.toml"),
    ]

    runtime_to_local_dir_pairs = nvim_build_path_pairs(
        nvim_cfg_base_dirs,
        runtime_nvim_dir=runtime_nvim_dir,
        local_nvim_dir=local_nvim_dir,
    )
    runtime_to_local_file_pairs = nvim_build_path_pairs(
        nvim_cfg_toplevel_files,
        runtime_nvim_dir=runtime_nvim_dir,
        local_nvim_dir=local_nvim_dir,
    )

    runtime_base_manifests = {
        rel_dir: nvim_build_subdir_manifest(
            runtime_nvim_dir / rel_dir,
            disk_accessor=disk,
        )
        for rel_dir in nvim_cfg_base_dirs
        if rel_dir.name != "lua"
    }
    local_base_manifests = {
        rel_dir: nvim_build_subdir_manifest(
            local_nvim_dir / rel_dir,
            disk_accessor=disk,
        )
        for rel_dir in nvim_cfg_base_dirs
        if rel_dir.name != "lua"
    }

    runtime_lua_subdir_manifest = nvim_build_lua_subdir_manifest(
        runtime_nvim_dir,
        log_details=log_details,
        disk_accessor=disk,
    )
    local_lua_subdir_manifest = nvim_build_lua_subdir_manifest(
        local_nvim_dir,
        log_details=log_details,
        disk_accessor=disk,
    )

    return NvimSyncPlan(
        protected_rel_templates=protected_rel_templates,
        runtime_to_local_dir_pairs=runtime_to_local_dir_pairs,
        runtime_to_local_file_pairs=runtime_to_local_file_pairs,
        runtime_lua_subdir_manifest=runtime_lua_subdir_manifest,
        local_lua_subdir_manifest=local_lua_subdir_manifest,
        runtime_base_manifests=runtime_base_manifests,
        local_base_manifests=local_base_manifests,
    )


def nvim_is_protected_path(path: Path, protected_local_paths: set[Path]) -> bool:
    """Check whether a path matches or contains a protected template path."""
    return any(
        path == protected_path or path in protected_path.parents
        for protected_path in protected_local_paths
    )


def nvim_file_differs(
    runtime_file_path: Path,
    local_file_path: Path,
    disk_accessor: DiskAccessor | None = None,
) -> bool:
    """Return True when the local file is missing or differs from runtime."""
    disk = _resolve_disk_accessor(disk_accessor)
    if not disk.exists(runtime_file_path):
        return False
    if not disk.exists(local_file_path):
        return True
    return disk.files_differ(runtime_file_path, local_file_path)


def nvim_missing_runtime_files(
    local_lua_subdir_manifest: NvimLuaSubdirManifest,
    runtime_lua_subdir_manifest: NvimLuaSubdirManifest,
    protected_rel_templates: set[Path],
) -> list[Path]:
    """Return local files that are absent from runtime and not protected."""
    return sorted(
        (
            local_lua_subdir_manifest.files
            - runtime_lua_subdir_manifest.files
            - protected_rel_templates
        ),
        key=str,
    )


def nvim_missing_runtime_dirs(
    local_nvim_dir: Path,
    local_lua_subdir_manifest: NvimLuaSubdirManifest,
    runtime_lua_subdir_manifest: NvimLuaSubdirManifest,
    protected_rel_templates: set[Path],
) -> list[Path]:
    """Return local directories absent from runtime, deepest-first."""
    protected_local_paths = {
        local_nvim_dir / rel_path for rel_path in protected_rel_templates
    }

    def _relative_path_depth(path: Path) -> int:
        return len(path.parts)

    candidate_dirs = sorted(
        (local_lua_subdir_manifest.dirs - runtime_lua_subdir_manifest.dirs),
        key=_relative_path_depth,
        reverse=True,
    )

    missing_runtime_dirs: list[Path] = []
    for rel_dir in candidate_dirs:
        local_dir_path = local_nvim_dir / rel_dir
        if Path("lua") == rel_dir:
            continue
        if nvim_is_protected_path(
            local_dir_path, protected_local_paths=protected_local_paths
        ):
            continue
        missing_runtime_dirs.append(rel_dir)

    return missing_runtime_dirs


def nvim_runtime_lua_file_pairs(
    runtime_lua_subdir_manifest: NvimLuaSubdirManifest,
    protected_rel_templates: set[Path],
    runtime_nvim_dir: Path,
    local_nvim_dir: Path,
) -> list[NvimPathPair]:
    """Build runtime/local file pairs for non-template lua files."""
    runtime_lua_files = sorted(
        runtime_lua_subdir_manifest.files - protected_rel_templates,
        key=str,
    )
    return nvim_build_path_pairs(
        runtime_lua_files,
        runtime_nvim_dir=runtime_nvim_dir,
        local_nvim_dir=local_nvim_dir,
    )


def nvim_partition_file_pairs(
    file_pairs: list[NvimPathPair],
    disk_accessor: DiskAccessor | None = None,
) -> tuple[list[NvimPathPair], list[NvimPathPair], list[NvimPathPair]]:
    """Split file pairs into add/update/unchanged buckets."""
    disk = _resolve_disk_accessor(disk_accessor)
    add_pairs: list[NvimPathPair] = []
    update_pairs: list[NvimPathPair] = []
    unchanged_pairs: list[NvimPathPair] = []

    for path_pair in file_pairs:
        runtime_path = path_pair.runtime_path
        local_path = path_pair.local_path
        if not nvim_file_differs(
            runtime_path,
            local_path,
            disk_accessor=disk,
        ):
            unchanged_pairs.append(path_pair)
            continue

        if disk.exists(local_path):
            update_pairs.append(path_pair)
        else:
            add_pairs.append(path_pair)

    return add_pairs, update_pairs, unchanged_pairs


def nvim_missing_parent_dirs(
    local_file_path: Path,
    stop_dir: Path,
    disk_accessor: DiskAccessor | None = None,
) -> set[Path]:
    """Return missing parent directories up to (and excluding) stop_dir."""
    disk = _resolve_disk_accessor(disk_accessor)
    missing_dirs: set[Path] = set()
    current_dir = local_file_path.parent

    while current_dir != stop_dir and not disk.exists(current_dir):
        missing_dirs.add(current_dir)
        current_dir = current_dir.parent

    return missing_dirs


def nvim_collect_sync_info_counts(
    local_nvim_dir: Path,
    runtime_nvim_dir: Path,
    disk_accessor: DiskAccessor | None = None,
) -> NvimSyncInfoCounts:
    """Collect filesystem and sync-change counts for nvim info output."""
    disk = _resolve_disk_accessor(disk_accessor)
    plan = nvim_build_sync_plan(
        local_nvim_dir=local_nvim_dir,
        runtime_nvim_dir=runtime_nvim_dir,
        log_details=False,
        disk_accessor=disk,
    )

    # 1) Compute managed-surface totals for runtime/local from the snapshot plan.
    # 2) Compute remove/add/update file counts by comparing runtime vs local manifests.
    # 3) Compute remove/add/update directory counts from base-dir manifests + file parent impact.
    # 4) Return a single summary structure used by `nvim info` and mimic verification.

    base_dir_pairs = [
        path_pair
        for path_pair in plan.runtime_to_local_dir_pairs
        if path_pair.local_path.name != "lua"
    ]

    runtime_total_dirs = len(plan.runtime_lua_subdir_manifest.dirs) + sum(
        (1 if manifest.exists else 0) + len(manifest.dirs)
        for manifest in plan.runtime_base_manifests.values()
    )
    runtime_total_files = len(plan.runtime_lua_subdir_manifest.files) + sum(
        len(manifest.files) for manifest in plan.runtime_base_manifests.values()
    )
    runtime_total_files += sum(
        1
        for path_pair in plan.runtime_to_local_file_pairs
        if disk.exists(path_pair.runtime_path)
    )

    local_total_dirs = len(plan.local_lua_subdir_manifest.dirs) + sum(
        (1 if manifest.exists else 0) + len(manifest.dirs)
        for manifest in plan.local_base_manifests.values()
    )
    local_total_files = len(plan.local_lua_subdir_manifest.files) + sum(
        len(manifest.files) for manifest in plan.local_base_manifests.values()
    )
    local_total_files += sum(
        1
        for path_pair in plan.runtime_to_local_file_pairs
        if disk.exists(path_pair.local_path)
    )

    missing_runtime_files = nvim_missing_runtime_files(
        local_lua_subdir_manifest=plan.local_lua_subdir_manifest,
        runtime_lua_subdir_manifest=plan.runtime_lua_subdir_manifest,
        protected_rel_templates=plan.protected_rel_templates,
    )
    missing_runtime_dirs = nvim_missing_runtime_dirs(
        local_nvim_dir=local_nvim_dir,
        local_lua_subdir_manifest=plan.local_lua_subdir_manifest,
        runtime_lua_subdir_manifest=plan.runtime_lua_subdir_manifest,
        protected_rel_templates=plan.protected_rel_templates,
    )

    top_level_add_pairs, top_level_update_pairs, _ = nvim_partition_file_pairs(
        plan.runtime_to_local_file_pairs,
        disk_accessor=disk,
    )
    lua_file_pairs = nvim_runtime_lua_file_pairs(
        runtime_lua_subdir_manifest=plan.runtime_lua_subdir_manifest,
        protected_rel_templates=plan.protected_rel_templates,
        runtime_nvim_dir=runtime_nvim_dir,
        local_nvim_dir=local_nvim_dir,
    )
    lua_add_pairs, lua_update_pairs, _ = nvim_partition_file_pairs(
        lua_file_pairs,
        disk_accessor=disk,
    )

    dirs_to_add: set[Path] = set()
    dirs_to_update: set[Path] = set()

    for path_pair in base_dir_pairs:
        rel_dir = path_pair.runtime_path.relative_to(runtime_nvim_dir)
        runtime_manifest = plan.runtime_base_manifests[rel_dir]
        local_manifest = plan.local_base_manifests[rel_dir]
        local_dir_path = path_pair.local_path
        if not local_manifest.exists:
            dirs_to_add.add(local_dir_path)
            continue

        if runtime_manifest != local_manifest:
            dirs_to_update.add(local_dir_path)

    changed_file_pairs = [
        *top_level_add_pairs,
        *top_level_update_pairs,
        *lua_add_pairs,
        *lua_update_pairs,
    ]
    for path_pair in changed_file_pairs:
        missing_parent_dirs = nvim_missing_parent_dirs(
            local_file_path=path_pair.local_path,
            stop_dir=local_nvim_dir,
            disk_accessor=disk,
        )
        if missing_parent_dirs:
            dirs_to_add.update(missing_parent_dirs)
        else:
            dirs_to_update.add(path_pair.local_path.parent)

    dirs_to_update -= dirs_to_add

    return NvimSyncInfoCounts(
        runtime_total_dirs=runtime_total_dirs,
        runtime_total_files=runtime_total_files,
        local_total_dirs=local_total_dirs,
        local_total_files=local_total_files,
        remove_dirs=len(missing_runtime_dirs),
        remove_files=len(missing_runtime_files),
        add_dirs=len(dirs_to_add),
        add_files=len(top_level_add_pairs) + len(lua_add_pairs),
        update_dirs=len(dirs_to_update),
        update_files=len(top_level_update_pairs) + len(lua_update_pairs),
    )


def nvim_remove_explicit_sync_targets(
    shell_op: ShellOp,
    local_nvim_dir: Path,
    runtime_to_local_dir_pairs: list[NvimPathPair],
    disk_accessor: DiskAccessor | None = None,
):
    """Remove explicit top-level sync targets while excluding lua subdir sync."""
    disk = _resolve_disk_accessor(disk_accessor)
    removable_dir_pairs = [
        path_pair
        for path_pair in runtime_to_local_dir_pairs
        if path_pair.local_path.name != "lua"
    ]

    if removable_dir_pairs:
        logging.info(f"{L.B} Removing dotfiles copy from {local_nvim_dir}")
        logging.info(
            f"{L.B} Explicit remove targets: {len(removable_dir_pairs)} directories"
        )
    else:
        logging.info(f"{L.C} Explicit remove targets: Nothing to do.")

    for path_pair in removable_dir_pairs:
        logging.info(f"{L.B} Removing directory {path_pair.local_path}")
        if not shell_op.dry_run and not disk.exists(path_pair.local_path):
            logging.info(f"{L.C} Skipping missing directory {path_pair.local_path}")
            continue

        try:
            shell_op.remove_tree(path_pair.local_path)
        except FileNotFoundError:
            logging.warning(
                f"{L.E} Failed to remove target directory {path_pair.local_path}"
            )


def nvim_prune_missing_runtime_local_lua_subdir_entries(
    shell_op: ShellOp,
    local_nvim_dir: Path,
    runtime_nvim_dir: Path,
    log_unchanged_info: bool,
    local_lua_subdir_manifest: NvimLuaSubdirManifest,
    runtime_lua_subdir_manifest: NvimLuaSubdirManifest,
    protected_rel_templates: set[Path],
    disk_accessor: DiskAccessor | None = None,
):
    """Prune missing runtime files and directories from the local lua subdir."""
    disk = _resolve_disk_accessor(disk_accessor)

    missing_runtime_files = nvim_missing_runtime_files(
        local_lua_subdir_manifest=local_lua_subdir_manifest,
        runtime_lua_subdir_manifest=runtime_lua_subdir_manifest,
        protected_rel_templates=protected_rel_templates,
    )
    missing_runtime_dirs = nvim_missing_runtime_dirs(
        local_nvim_dir=local_nvim_dir,
        local_lua_subdir_manifest=local_lua_subdir_manifest,
        runtime_lua_subdir_manifest=runtime_lua_subdir_manifest,
        protected_rel_templates=protected_rel_templates,
    )

    if missing_runtime_files or missing_runtime_dirs:
        logging.info(f"{L.B} Pruning missing runtime lua entries from {local_nvim_dir}")
        logging.info(
            f"{L.B} Missing runtime prune targets:"
            f" {len(missing_runtime_files)} files, {len(missing_runtime_dirs)} directories"
        )
    else:
        logging.info(f"{L.C} Missing runtime prune targets: Nothing to do.")

    for rel_file in missing_runtime_files:
        local_file_path = local_nvim_dir / rel_file
        if rel_file in protected_rel_templates:
            if log_unchanged_info:
                logging.info(f"{L.C} Preserving protected template {local_file_path}")
            continue

        logging.info(f"{L.B} Removing missing runtime file {local_file_path}")
        if not shell_op.dry_run:
            runtime_file_path = runtime_nvim_dir / rel_file
            if disk.exists(runtime_file_path):
                logging.info(
                    f"{L.C} Skipping remove due runtime drift {local_file_path}"
                )
                continue

        shell_op.unlink_file(local_file_path)

    for rel_dir in missing_runtime_dirs:
        local_dir_path = local_nvim_dir / rel_dir
        logging.info(f"{L.B} Removing missing runtime dir {local_dir_path}")
        if not shell_op.dry_run:
            runtime_dir_path = runtime_nvim_dir / rel_dir
            if disk.exists(runtime_dir_path):
                logging.info(
                    f"{L.C} Skipping remove due runtime drift {local_dir_path}"
                )
                continue
            if not disk.exists(local_dir_path):
                logging.info(f"{L.C} Skipping missing directory {local_dir_path}")
                continue

        try:
            shell_op.remove_tree(local_dir_path)
        except FileNotFoundError:
            logging.warning(
                f"{L.E} Failed to remove missing runtime dir {local_dir_path}"
            )


def nvim_copy_from_runtime_to_local(
    shell_op: ShellOp,
    local_nvim_dir: Path,
    runtime_nvim_dir: Path,
    log_unchanged_info: bool,
    runtime_to_local_dir_pairs: list[NvimPathPair],
    runtime_to_local_file_pairs: list[NvimPathPair],
    disk_accessor: DiskAccessor | None = None,
):
    """Copy top-level sync targets not managed through lua subdir manifest."""
    disk = _resolve_disk_accessor(disk_accessor)
    logging.info(f"{L.B} Copying nvim config {runtime_nvim_dir} -> {local_nvim_dir}")

    base_copy_dir_pairs = [
        path_pair
        for path_pair in runtime_to_local_dir_pairs
        if path_pair.local_path.name != "lua"
    ]
    top_add_pairs, top_update_pairs, top_unchanged_pairs = nvim_partition_file_pairs(
        runtime_to_local_file_pairs,
        disk_accessor=disk,
    )

    logging.info(
        f"{L.B} Base directory copy targets: {len(base_copy_dir_pairs)} directories"
    )
    if top_add_pairs or top_update_pairs:
        logging.info(
            f"{L.B} Top-level file copy targets:"
            f" add={len(top_add_pairs)} update={len(top_update_pairs)}"
            f" unchanged={len(top_unchanged_pairs)}"
        )
    else:
        logging.info(f"{L.C} Top-level file copy targets: Nothing to do.")

    for path_pair in base_copy_dir_pairs:
        logging.info(
            f"{L.B} Copying base directory (non-lua)"
            f" {path_pair.runtime_path} -> {path_pair.local_path}"
        )
        if not shell_op.dry_run and not disk.exists(path_pair.runtime_path):
            logging.warning(
                f"{L.E} Skipping copy because runtime dir is missing {path_pair.runtime_path}"
            )
            continue
        shell_op.copy_tree(path_pair.runtime_path, path_pair.local_path)

    for path_pair in [*top_add_pairs, *top_update_pairs]:
        runtime_path = path_pair.runtime_path
        local_path = path_pair.local_path
        logging.info(
            f"{L.B} Copying top-level file because runtime file differs"
            f" {runtime_path} -> {local_path}"
        )
        if not shell_op.dry_run and not nvim_file_differs(
            runtime_path,
            local_path,
            disk_accessor=disk,
        ):
            logging.info(f"{L.C} Skipping copy due drift {local_path}")
            continue
        shell_op.copy_file(runtime_path, local_path)

    if log_unchanged_info:
        for path_pair in top_unchanged_pairs:
            local_path = path_pair.local_path
            logging.info(f"{L.C} Skipping unchanged top-level file {local_path}")


def nvim_copy_lua_subdir_manifest(
    shell_op: ShellOp,
    local_nvim_dir: Path,
    runtime_nvim_dir: Path,
    log_unchanged_info: bool,
    runtime_lua_subdir_manifest: NvimLuaSubdirManifest,
    protected_rel_templates: set[Path],
    disk_accessor: DiskAccessor | None = None,
):
    """Copy every non-template file in the Lua subdir manifest into local."""
    disk = _resolve_disk_accessor(disk_accessor)
    lua_file_pairs = nvim_runtime_lua_file_pairs(
        runtime_lua_subdir_manifest=runtime_lua_subdir_manifest,
        protected_rel_templates=protected_rel_templates,
        runtime_nvim_dir=runtime_nvim_dir,
        local_nvim_dir=local_nvim_dir,
    )
    lua_add_pairs, lua_update_pairs, lua_unchanged_pairs = nvim_partition_file_pairs(
        lua_file_pairs,
        disk_accessor=disk,
    )

    logging.info(
        f"{L.B} Copying lua subdir files {runtime_nvim_dir} -> {local_nvim_dir}"
    )
    if lua_add_pairs or lua_update_pairs:
        logging.info(
            f"{L.B} Lua subdir file copy targets:"
            f" add={len(lua_add_pairs)} update={len(lua_update_pairs)}"
            f" unchanged={len(lua_unchanged_pairs)}"
        )
    else:
        logging.info(f"{L.C} Lua subdir file copy targets: Nothing to do.")

    for path_pair in [*lua_add_pairs, *lua_update_pairs]:
        runtime_file_path = path_pair.runtime_path
        local_file_path = path_pair.local_path
        logging.info(
            f"{L.B} Copying Lua subdir file {runtime_file_path} -> {local_file_path}"
        )
        if not shell_op.dry_run and not nvim_file_differs(
            runtime_file_path, local_file_path, disk_accessor=disk
        ):
            logging.info(f"{L.C} Skipping copy due drift {local_file_path}")
            continue
        shell_op.ensure_parent_dir(local_file_path)
        shell_op.copy_file(runtime_file_path, local_file_path)

    if log_unchanged_info:
        for path_pair in lua_unchanged_pairs:
            local_file_path = path_pair.local_path
            logging.info(f"{L.C} Skipping unchanged Lua subdir file {local_file_path}")


def nvim_sync(
    dry_run: bool,
    branch: str,
    local_nvim_dir: Path,
    runtime_nvim_dir: Path,
    log_unchanged_info: bool,
    disk_accessor: DiskAccessor | None = None,
):
    """Coordinate the full runtime-to-local Neovim sync process."""
    disk = _resolve_disk_accessor(disk_accessor)
    shell_op: ShellOp = DryShellOp() if dry_run else RealShellOp()

    sync_plan = nvim_build_sync_plan(
        local_nvim_dir=local_nvim_dir,
        runtime_nvim_dir=runtime_nvim_dir,
        log_details=True,
        disk_accessor=disk,
    )

    logging.info(
        f"{L.B} Will copy nvim config from '{branch}' branch"
        f" {runtime_nvim_dir} -> {local_nvim_dir}"
    )

    nvim_remove_explicit_sync_targets(
        shell_op=shell_op,
        local_nvim_dir=local_nvim_dir,
        runtime_to_local_dir_pairs=sync_plan.runtime_to_local_dir_pairs,
        disk_accessor=disk,
    )
    nvim_prune_missing_runtime_local_lua_subdir_entries(
        shell_op=shell_op,
        local_nvim_dir=local_nvim_dir,
        runtime_nvim_dir=runtime_nvim_dir,
        log_unchanged_info=log_unchanged_info,
        local_lua_subdir_manifest=sync_plan.local_lua_subdir_manifest,
        runtime_lua_subdir_manifest=sync_plan.runtime_lua_subdir_manifest,
        protected_rel_templates=sync_plan.protected_rel_templates,
        disk_accessor=disk,
    )
    nvim_copy_from_runtime_to_local(
        shell_op=shell_op,
        local_nvim_dir=local_nvim_dir,
        runtime_nvim_dir=runtime_nvim_dir,
        log_unchanged_info=log_unchanged_info,
        runtime_to_local_dir_pairs=sync_plan.runtime_to_local_dir_pairs,
        runtime_to_local_file_pairs=sync_plan.runtime_to_local_file_pairs,
        disk_accessor=disk,
    )
    nvim_copy_lua_subdir_manifest(
        shell_op=shell_op,
        local_nvim_dir=local_nvim_dir,
        runtime_nvim_dir=runtime_nvim_dir,
        log_unchanged_info=log_unchanged_info,
        runtime_lua_subdir_manifest=sync_plan.runtime_lua_subdir_manifest,
        protected_rel_templates=sync_plan.protected_rel_templates,
        disk_accessor=disk,
    )


def _resolve_nvim_paths(
    project_dir: Path,
    default_runtime_nvim_dir: Path,
    nvim_config_dir: str | None,
    local_nvim_dir_override: Path | None = None,
    runtime_nvim_dir_override: Path | None = None,
) -> tuple[Path, Path]:
    runtime_nvim_dir = runtime_nvim_dir_override or Path(
        nvim_config_dir or str(default_runtime_nvim_dir)
    )
    local_nvim_dir = local_nvim_dir_override or (project_dir / "home/dot_config/nvim")
    return runtime_nvim_dir, local_nvim_dir


def nvim_sync_with_mimic(args: NvimSyncWithMimicArgs) -> None:
    """Run sync directly or against a temporary local mimic copy."""
    runtime_nvim_dir, local_nvim_dir = _resolve_nvim_paths(
        project_dir=args.project_dir,
        default_runtime_nvim_dir=args.default_runtime_nvim_dir,
        nvim_config_dir=args.nvim_config_dir,
    )
    disk_accessor = args.disk_accessor

    if not is_git_clean(str(runtime_nvim_dir)):
        logging.warning(
            f"{L.E} There are un-committed changes."
            " Please commit all changes first before copying them into dotfiles.",
        )
        return

    branch = git_branch(str(runtime_nvim_dir))
    if "master" != branch:
        if args.override_branch_name is not None:
            if branch == args.override_branch_name:
                logging.info(
                    f"{L.B} Copying nvim config from current branch '{args.override_branch_name}'"
                )
            else:
                logging.warning(
                    f"{L.E} The current nvim config branch is '{branch}'. To copy its"
                    f" config specify that instead of '{args.override_branch_name}' as "
                    " the override."
                )
                return
        else:
            logging.warning(
                f"{L.E} nvim config branch must be 'master' to copy config (by default)."
                f" Pass '--override-branch-name={branch}' to copy from the current branch."
            )
            return

    if args.mimic and not args.dry_run:
        logging.warning(f"{L.E} --mimic cannot be used with --no-dry-run")
        return

    if not args.mimic:
        nvim_sync(
            dry_run=args.dry_run,
            branch=branch,
            local_nvim_dir=local_nvim_dir,
            runtime_nvim_dir=runtime_nvim_dir,
            log_unchanged_info=args.log_unchanged_info,
            disk_accessor=args.disk_accessor,
        )
        return

    mimic_root = Path(tempfile.mkdtemp(prefix="dotfiles_nvim_mimic_"))
    mimicked_local_nvim_dir = mimic_root / "nvim"
    _ = shutil.copytree(local_nvim_dir, mimicked_local_nvim_dir)

    logging.info(
        f"{L.B} Mimic mode using temporary local nvim directory {mimicked_local_nvim_dir}"
    )

    try:
        nvim_sync(
            dry_run=False,
            branch=branch,
            local_nvim_dir=mimicked_local_nvim_dir,
            runtime_nvim_dir=runtime_nvim_dir,
            log_unchanged_info=args.log_unchanged_info,
            disk_accessor=disk_accessor,
        )

        logging.info(f"{L.B} Verifying mimic sync result")
        info_counts = nvim_info(
            NvimInfoArgs(
                nvim_config_dir=None,
                project_dir=args.project_dir,
                default_runtime_nvim_dir=args.default_runtime_nvim_dir,
                disk_accessor=disk_accessor,
                local_nvim_dir_override=mimicked_local_nvim_dir,
                runtime_nvim_dir_override=runtime_nvim_dir,
            )
        )
        has_pending_changes = any(
            [
                0 != info_counts.remove_dirs,
                0 != info_counts.remove_files,
                0 != info_counts.add_dirs,
                0 != info_counts.add_files,
                0 != info_counts.update_dirs,
                0 != info_counts.update_files,
            ]
        )
        if has_pending_changes:
            logging.warning(
                f"{L.E} Mimic verification found remaining local changes"
                f" remove(d={info_counts.remove_dirs},f={info_counts.remove_files})"
                f" add(d={info_counts.add_dirs},f={info_counts.add_files})"
                f" update(d={info_counts.update_dirs},f={info_counts.update_files})"
            )
        else:
            logging.info(f"{L.C} Mimic verification passed: no remaining changes")
    finally:
        shutil.rmtree(mimic_root, ignore_errors=True)


def nvim_info(args: NvimInfoArgs) -> NvimSyncInfoCounts:
    """Log nvim sync counts and return them."""
    runtime_nvim_dir, local_nvim_dir = _resolve_nvim_paths(
        project_dir=args.project_dir,
        default_runtime_nvim_dir=args.default_runtime_nvim_dir,
        nvim_config_dir=args.nvim_config_dir,
        local_nvim_dir_override=args.local_nvim_dir_override,
        runtime_nvim_dir_override=args.runtime_nvim_dir_override,
    )
    info_counts = nvim_collect_sync_info_counts(
        local_nvim_dir=local_nvim_dir,
        runtime_nvim_dir=runtime_nvim_dir,
        disk_accessor=args.disk_accessor,
    )

    logging.info(
        f"{L.A} Runtime totals dirs={info_counts.runtime_total_dirs}"
        f" files={info_counts.runtime_total_files}"
    )
    logging.info(
        f"{L.A} Local totals   dirs={info_counts.local_total_dirs}"
        f" files={info_counts.local_total_files}"
    )
    logging.info(
        f"{L.B} Local remove   dirs={info_counts.remove_dirs}"
        f" files={info_counts.remove_files}"
    )
    logging.info(
        f"{L.B} Local add      dirs={info_counts.add_dirs}"
        f" files={info_counts.add_files}"
    )
    logging.info(
        f"{L.B} Local update   dirs={info_counts.update_dirs}"
        f" files={info_counts.update_files}"
    )

    return info_counts
