from pathlib import Path

from dotfiles.nvim import (
    NvimLuaSubdirManifest,
    nvim_build_path_pairs,
    nvim_is_protected_path,
    nvim_missing_runtime_dirs,
    nvim_missing_runtime_files,
    nvim_runtime_lua_file_pairs,
)


def test_build_path_pairs_maps_runtime_and_local_paths() -> None:
    """Build runtime/local pairs from relative nvim paths.

    GIVEN
    Relative nvim paths with runtime and local base directories.

    WHEN
    Path-pair mapping is generated.

    Then
    Each pair maps to the expected runtime and local absolute paths.
    """

    rel_paths = [Path("lua"), Path("init.lua"), Path("after") / "ftplugin"]
    runtime_nvim_dir = Path("/runtime/nvim")
    local_nvim_dir = Path("/local/nvim")

    pairs = nvim_build_path_pairs(
        rel_paths,
        runtime_nvim_dir=runtime_nvim_dir,
        local_nvim_dir=local_nvim_dir,
    )

    assert [pair.runtime_path for pair in pairs] == [
        Path("/runtime/nvim/lua"),
        Path("/runtime/nvim/init.lua"),
        Path("/runtime/nvim/after/ftplugin"),
    ]
    assert [pair.local_path for pair in pairs] == [
        Path("/local/nvim/lua"),
        Path("/local/nvim/init.lua"),
        Path("/local/nvim/after/ftplugin"),
    ]


def test_is_protected_path_matches_exact_and_parent_paths() -> None:
    """Treat protected template path and its parents as protected.

    GIVEN
    A protected template file path under local nvim config.

    WHEN
    Exact, parent, and unrelated paths are checked.

    Then
    Exact and parent paths match, while unrelated paths do not.
    """

    protected = {Path("/local/nvim/lua/plugins/symlink_user-config.tmpl")}

    assert nvim_is_protected_path(
        Path("/local/nvim/lua/plugins/symlink_user-config.tmpl"),
        protected_local_paths=protected,
    )
    assert nvim_is_protected_path(
        Path("/local/nvim/lua/plugins"),
        protected_local_paths=protected,
    )
    assert not nvim_is_protected_path(
        Path("/local/nvim/lua/custom"),
        protected_local_paths=protected,
    )


def test_missing_runtime_files_excludes_protected_templates_and_sorts() -> None:
    """Find missing local files while excluding protected templates.

    GIVEN
    Local/runtime manifests and a protected template path.

    WHEN
    Missing runtime files are computed.

    Then
    Only non-protected missing files are returned.
    """

    local_manifest = NvimLuaSubdirManifest(
        dirs={Path("lua")},
        files={
            Path("lua/a.lua"),
            Path("lua/plugins/symlink_user-config.tmpl"),
            Path("lua/z.lua"),
        },
    )
    runtime_manifest = NvimLuaSubdirManifest(
        dirs={Path("lua")},
        files={Path("lua/a.lua")},
    )
    protected_templates = {Path("lua/plugins/symlink_user-config.tmpl")}

    result = nvim_missing_runtime_files(
        local_lua_subdir_manifest=local_manifest,
        runtime_lua_subdir_manifest=runtime_manifest,
        protected_rel_templates=protected_templates,
    )

    assert result == [Path("lua/z.lua")]


def test_missing_runtime_dirs_skips_lua_root_and_protected_dirs() -> None:
    """Prune missing directories while preserving protected and root paths.

    GIVEN
    Local/runtime dir manifests with protected template ancestry.

    WHEN
    Missing runtime directories are calculated.

    Then
    Only removable missing dirs are returned in deepest-first order.
    """

    local_manifest = NvimLuaSubdirManifest(
        dirs={
            Path("lua"),
            Path("lua/plugins"),
            Path("lua/plugins/custom"),
            Path("lua/obsolete"),
            Path("lua/obsolete/deep"),
            Path("lua/keep"),
        },
        files=set(),
    )
    runtime_manifest = NvimLuaSubdirManifest(
        dirs={Path("lua"), Path("lua/keep")},
        files=set(),
    )
    protected_templates = {Path("lua/plugins/symlink_user-config.tmpl")}

    result = nvim_missing_runtime_dirs(
        local_nvim_dir=Path("/local/nvim"),
        local_lua_subdir_manifest=local_manifest,
        runtime_lua_subdir_manifest=runtime_manifest,
        protected_rel_templates=protected_templates,
    )

    assert set(result) == {
        Path("lua/plugins/custom"),
        Path("lua/obsolete"),
        Path("lua/obsolete/deep"),
    }
    # Missing directories must be returned deepest-first so prune operations can
    # remove children before parents without hitting non-empty parent errors.
    depths = [len(path.parts) for path in result]
    assert depths == sorted(depths, reverse=True)


def test_runtime_lua_file_pairs_excludes_protected_and_is_sorted() -> None:
    """Build runtime-to-local file pairs excluding protected templates.

    GIVEN
    A runtime Lua file manifest containing protected and regular files.

    WHEN
    Runtime Lua file pairs are generated.

    Then
    Pairs exclude protected files and are returned in sorted order.
    """

    runtime_manifest = NvimLuaSubdirManifest(
        dirs={Path("lua")},
        files={
            Path("lua/z.lua"),
            Path("lua/plugins/symlink_os-config.tmpl"),
            Path("lua/a.lua"),
        },
    )
    protected_templates = {Path("lua/plugins/symlink_os-config.tmpl")}

    pairs = nvim_runtime_lua_file_pairs(
        runtime_lua_subdir_manifest=runtime_manifest,
        protected_rel_templates=protected_templates,
        runtime_nvim_dir=Path("/runtime/nvim"),
        local_nvim_dir=Path("/local/nvim"),
    )

    assert [pair.runtime_path for pair in pairs] == [
        Path("/runtime/nvim/lua/a.lua"),
        Path("/runtime/nvim/lua/z.lua"),
    ]
    assert [pair.local_path for pair in pairs] == [
        Path("/local/nvim/lua/a.lua"),
        Path("/local/nvim/lua/z.lua"),
    ]
