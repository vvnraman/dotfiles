import configparser
from pathlib import Path

# Configuration file for the Sphinx documentation builder.
#
# This file only contains a selection of the most common options. For a full
# list see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Path setup --------------------------------------------------------------

# If extensions (or modules to document with autodoc) are in another directory,
# add these directories to sys.path here. If the directory is relative to the
# documentation root, use os.path.abspath to make it absolute, like shown here.
#
# import os
# import sys
# sys.path.insert(0, os.path.abspath('.'))


# -- Project information -----------------------------------------------------

project = "vvnraman's dotfiles"
copyright = "Prateek Raman"
author = "Prateek Raman"

# The full version, including alpha/beta/rc tags
release = "0.1.0"


DEFAULT_PUBLISH_HOST = "https://vvnraman.github.io"


def _project_root() -> Path:
    return Path(__file__).resolve().parent.parent


def _publish_config_path() -> Path:
    return _project_root() / "python" / "dotfiles-config.ini"


def _load_publish_host() -> str:
    config_path = _publish_config_path()
    if not config_path.exists():
        return DEFAULT_PUBLISH_HOST

    config = configparser.ConfigParser()
    try:
        _ = config.read(config_path)
    except configparser.Error:
        return DEFAULT_PUBLISH_HOST

    publish_host = config.get("publish", "publish_host", fallback=DEFAULT_PUBLISH_HOST)
    return publish_host.rstrip("/")


PUBLISH_HOST = _load_publish_host()


# -- General configuration ---------------------------------------------------

# Add any Sphinx extension module names here, as strings. They can be
# extensions coming with Sphinx (named 'sphinx.ext.*') or your custom
# ones.
extensions = [
    "sphinx.ext.extlinks",
    "sphinx.ext.graphviz",
    "sphinxcontrib.mermaid",
    "sphinxemoji.sphinxemoji",
    "sphinx_design",
]

extensions.extend(
    [
        "dotfiles.sphinxext.layout_generator",
        "dotfiles.sphinxext.help_generator",
    ]
)

# Add any paths that contain templates here, relative to this directory.
templates_path = ["_templates"]

extlinks = {
    "dotfiles-docs": (f"{PUBLISH_HOST}/dotfiles%s", "%s"),
    "neovim-docs": (f"{PUBLISH_HOST}/neovim-config%s", "%s"),
}

# List of patterns, relative to source directory, that match files and
# directories to ignore when looking for source files.
# This pattern also affects html_static_path and html_extra_path.
exclude_patterns = ["_build", "Thumbs.db", ".DS_Store"]


# -- Options for HTML output -------------------------------------------------

# The theme to use for HTML and HTML Help pages.  See the documentation for
# a list of builtin themes.
#
html_theme = "pydata_sphinx_theme"

# Add any paths that contain custom static files (such as style sheets) here,
# relative to this directory. They are copied after the builtin static files,
# so a file named "default.css" will overwrite the builtin "default.css".
# html_static_path = ["_static"]
