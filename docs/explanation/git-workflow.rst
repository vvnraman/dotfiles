.. _explanation-git-workflow:

Git workflow
============

``mg`` is the shared git workflow command installed at ``~/.local/bin/mg`` from
``home/dot_local/bin/executable_mg``. It manages the bare-plus-worktree layout I use.

Defaults and env
^^^^^^^^^^^^^^^^

- ``VVN_DOTFILES_GITHUB_HOST`` sets default host for ``mg clone`` org/repo form.
- If unset, default host is ``github``.
- ``<host-alias>`` refers to your SSH alias in ``~/.ssh/config``.
- ``MG_GIT_VERBOSE=1`` enables shell tracing for ``mg`` command execution.

Common command examples
-----------------------

.. dropdown:: Show ``mg init --example`` output

   .. literalinclude:: ../generated/mg-init-example.txt
      :language: text
      :caption: mg init --example output

.. dropdown:: Show ``mg clone --example`` output

   .. literalinclude:: ../generated/mg-clone-example.txt
      :language: text
      :caption: mg clone --example output

.. dropdown:: Show ``mg switch --example`` output

   .. literalinclude:: ../generated/mg-switch-example.txt
      :language: text
      :caption: mg switch --example output

.. dropdown:: Show ``mg new-branch --example`` output

   .. literalinclude:: ../generated/mg-new-branch-example.txt
      :language: text
      :caption: mg new-branch --example output

.. dropdown:: Show ``mg self-branch --example`` output

   .. literalinclude:: ../generated/mg-self-branch-example.txt
      :language: text
      :caption: mg self-branch --example output

.. dropdown:: Show ``mg alien-branch --example`` output

   .. literalinclude:: ../generated/mg-alien-branch-example.txt
      :language: text
      :caption: mg alien-branch --example output

mg command help
---------------

.. dropdown:: Show ``mg --help`` output

   .. literalinclude:: ../generated/mg-help.txt
      :language: text
      :caption: mg --help output

Implementation details
----------------------

- See :ref:`Git scripts <explanation-git-scripts>` for runtime dispatch, include guards, and wrapper internals.

Relevant changelogs
-------------------

- :ref:`2026-03-mar - expand mg workflow commands <changelog-2026-03-mar-expand-mg-workflow-commands>`
- :ref:`2026-03-mar - consolidate mg git workflow wrappers <changelog-2026-03-mar-consolidate-mg-git-workflow-wrappers>`
