.. _explanation-chezmoi-data:

Chezmoi data
============

This page explains the static data files that templates read during rendering.
Data files keep machine path rules in one place so templates can stay small.

Data files in this repo
-----------------------

- ``home/.chezmoidata/executable-paths.toml`` stores executable lookup paths by OS.
- The data separates ``home_relative`` entries from ``absolute`` entries.
- ``home_relative`` paths are joined with ``.chezmoi.homeDir`` by template helpers.

.. literalinclude:: ../../../home/.chezmoidata/executable-paths.toml
   :language: toml
   :lineno-match:
   :emphasize-lines: 1,2,3,5,6,13
   :caption: executable-paths.toml

Operational notes
-----------------

- Data in ``.chezmoidata`` merges into template context and is available as top-level keys.
- Keep these files static; they are not template files.
- Use ``chezmoi data`` to inspect the merged data dictionary on a machine.
