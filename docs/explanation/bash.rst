.. _explanation-bash-configuration:

Bash configuration
==================

``bash`` is our default shell, but we use ``fish`` for all interactive purposes. The ``bash`` setup
is modular to achieve the following outcomes

- ``bashrc`` drives the config, with separate files for setting various pices of config such that
  the separate scripts "look" similar in structure to our ``fish`` counterparts.

- Machine-specific customization is overlayed via os and user sepcific files in a declarative
  manner.

- Exactly which os and which user file gets included is determined via ``chezmoi`` generated
  symlinks.

Directory layout
----------------

.. dropdown:: Show layout

   .. literalinclude:: ../generated/bash-layout.txt
      :language: sh
      :caption: home/dot-bash

Load order
----------

Implicit Bash startup behavior

- Login bash reads ``.bash_profile`` (or ``.bash_login`` / ``.profile``).

- Interactive non-login bash reads ``.bashrc``.

Our explicit startup order is the following:

1. ``bash_profile`` loads ``profile``

   .. literalinclude:: ../../home/dot-bash/bash_profile
      :language: bash
      :lineno-match:
      :emphasize-lines: 3
      :caption: bash_profile

2. ``profile`` loads ``bashrc``

   .. literalinclude:: ../../home/dot-bash/profile
      :language: bash
      :lineno-match:
      :emphasize-lines: 14
      :caption: profile

Explicit order inside ``bashrc``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

1. ``bashrc`` loads ``.sh`` scripts from ``bashrc.d/`` directory
2. ``bashrc`` loads ``overlays/bashrc-linwin.sh``
3. ``bashrc`` loads OS and user specific overlays

   .. literalinclude:: ../../home/dot-bash/bashrc
      :language: bash
      :lines: 53-67
      :lineno-match:
      :emphasize-lines: 7,11,14,15
      :caption: bashrc

4. Linux distro agnostic config is present in ``dot-bash/overlays/bashrc-os-linux.sh``, which gets
   loaded by the distro specific bash config symlinked via chezmoi template
   ``dot-bash/overlays/symlink_bashrc-os-config.sh.tmpl``.

   .. tab-set::

      .. tab-item:: Arch

         .. literalinclude:: ../../home/dot-bash/overlays/bashrc-os-linux-arch.sh
            :language: ini
            :lineno-match:
            :emphasize-lines: 5
            :caption: bashrc-os-linux-arch.sh

      .. tab-item:: Ubuntu

         .. literalinclude:: ../../home/dot-bash/overlays/bashrc-os-linux-ubuntu.sh
            :language: ini
            :lineno-match:
            :emphasize-lines: 5,9
            :caption: bashrc-os-linux-ubuntu.sh

----

Relevant changelogs
-------------------

- :ref:`2026-02-feb - restructure bash config modules <changelog-2026-02-feb-restructure-bash-config-modules>`
