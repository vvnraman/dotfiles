#!/usr/bin/env bash
set -euo pipefail

script_dir="$(dirname "${BASH_SOURCE[0]}")"
SHELL_UNDER_TEST=bash bats "${script_dir}/git-shell.bats" "$@"
