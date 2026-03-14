****************
Run Python tests
****************

Run all tests
=============

From the repository root:

.. code-block:: sh

   make test

Runs ``pytest`` for the Python project at ``python/``.

Run pytest directly
===================

From the repository root:

.. code-block:: sh

   uv run --project python --group dev pytest python/tests

Run one file or one test
========================

.. code-block:: sh

   uv run --project python --group dev pytest python/tests/test_nvim_pure_logic.py
   uv run --project python --group dev pytest python/tests/test_nvim_pure_logic.py::test_build_path_pairs_maps_runtime_and_local_paths
