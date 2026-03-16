.. _explanation-python-source-root-resolution:

Source root resolution module
=============================

``python/src/dotfiles/paths.py`` resolves the dotfiles repository root used by
CLI commands and Sphinx helper extensions.

High-level structure
--------------------

.. code-block:: text

   paths.py
   |-- constants
   |   |-- PROJECT_MARKERS
   |   |-- CONFIG_SECTION_PATHS / CONFIG_KEY_GIT_ROOT
   |   `-- CHEZMOI_DOTFILES_PATH_OVERRIDE
   |-- IO boundary
   |   |-- SourceRootResolutionIO
   |   `-- RealSourceRootResolutionIO
   |-- tracing and context
   |   |-- DiscoveryTrace
   |   `-- ResolverContext
   |-- strategy helpers
   |   |-- _resolve_direct_project_root
   |   |-- _resolve_from_runtime_package_path
   |   |-- _config_git_root
   |   `-- _resolve_from_chezmoi_source_path
   `-- public API
       |-- package_config_path
       |-- set_source_root_override
       |-- resolve_project_dir_with_io
       |-- show_project_dir_discovery
       `-- resolve_project_dir

- Keeps source-root resolution in one module used by CLI and docs helpers.
- Separates filesystem and process access behind ``SourceRootResolutionIO``.
- Uses ``DiscoveryTrace`` to record and optionally stream strategy attempts.
- Raises ``SourceRootResolutionError`` with ordered strategy output on failure.

Resolution order
----------------

1. ``--source-root`` (set through ``set_source_root_override``).
2. Runtime package path ancestry (walk up from package/config location).
3. ``[paths].git_root`` in ``dotfiles-config.ini``.
4. ``chezmoi source-path`` walk-up to project markers.
5. ``CHEZMOI_DOTFILES_PATH_OVERRIDE``.

If ``--source-root`` is provided and invalid, resolution stops immediately and
does not continue to fallback strategies.

Runtime behavior
----------------

- ``uv run --project python dotfiles ...`` resolves to the active checkout when
  the package path is inside that checkout.
- Installed entrypoints can still resolve through configured ``git_root`` and
  other fallbacks when package ancestry is not a repository root.
- Sphinx extension hooks call ``resolve_project_dir`` and reuse the same logic.

Cache and diagnostics
---------------------

- ``resolve_project_dir`` is memoized with ``@lru_cache(maxsize=1)``.
- ``set_source_root_override`` clears the cache so subsequent commands use the
  latest override.
- ``show_project_dir_discovery`` emits each trace line for
  ``--show-source-discovery``.

Relevant changelogs
-------------------

- :ref:`2026-03-mar - rework python installer and cli discovery <changelog-2026-03-mar-rework-python-installer-and-cli-discovery>`
- :ref:`2026-03-mar - refactor python cli config and nvim io <changelog-2026-03-mar-refactor-python-cli-config-and-nvim-io>`
