.. _explanation-chezmoi-machine-specific-config:

Machine specific config
=======================

This repo uses one shared dotfiles source while still allowing each machine to load the right
variant of a config file. The selection is deterministic and based on machine identity signals
and environment values available to chezmoi during rendering.

Generic selection mechanism
---------------------------

The machine identity selectors are built from three reusable templates:

- ``os-config`` from ``os-config.tmpl``
- ``user-config`` from ``user-config.tmpl``
- ``os-user-config`` from ``os-user-config.tmpl``

.. literalinclude:: ../../../home/.chezmoitemplates/os-config.tmpl
   :language: text
   :lineno-match:
   :emphasize-lines: 2,3,4,5
   :caption: os-config.tmpl

.. literalinclude:: ../../../home/.chezmoitemplates/user-config.tmpl
   :language: text
   :lineno-match:
   :emphasize-lines: 2
   :caption: user-config.tmpl

.. literalinclude:: ../../../home/.chezmoitemplates/os-user-config.tmpl
   :language: text
   :lineno-match:
   :emphasize-lines: 2,3,4
   :caption: os-user-config.tmpl

Symlink templates use these selectors to resolve a candidate target name. If that candidate exists
in source state, chezmoi creates a symlink to it.

No-op fallback for fault tolerance
----------------------------------

Each symlink selector also checks whether the computed candidate exists in source state before
emitting it. If the candidate is missing, the template falls back to a no-op target file.

This keeps the generated symlink valid even when a machine-specific variant is not present.

.. code-block:: text
   :caption: Generic robust selector pattern

   {{- $source_dir := joinPath .chezmoi.sourceDir "<config-root>" -}}
   {{- $candidate := print "<prefix>-" (includeTemplate "os-config.tmpl" .) "<suffix>" -}}
   {{- if stat (joinPath $source_dir $candidate) -}}
   {{ $candidate }}
   {{- else -}}
   no-op.<ext>
   {{- end -}}

Selection flow
--------------

1. Chezmoi evaluates a symlink template.
2. The template renders a selector value (os, user, or os-user).
3. The template builds a candidate target name from that selector.
4. If the candidate exists in source state, it is used.
5. If the candidate is missing, the no-op target is used.
6. Chezmoi creates the symlink to the selected target.

Where this is used
------------------

- :ref:`explanation-bash-configuration`
- :ref:`explanation-fish-configuration`
- :ref:`explanation-git-configuration`
