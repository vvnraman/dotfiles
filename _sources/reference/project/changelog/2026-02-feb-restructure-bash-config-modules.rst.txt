.. _changelog-2026-02-feb-restructure-bash-config-modules:

2026-02 feb - restructure bash config modules
=============================================

2026-02-28 - Saturday
---------------------

Restructure bash config modules.

Change summary
--------------

- Split monolithic bash startup into modular files:
  ``bashrc-lib.sh``, ``bashrc-rest.sh``, and ``bashrc.d`` modules.
- Added OS/user overlay symlink selectors for bash startup overlays.
- Removed older machine-specific ``bashrc-custom*`` fragments and moved shared
  behavior into composable modules.

Related explanation
-------------------

- :ref:`Bash configuration <explanation-bash-configuration>`
