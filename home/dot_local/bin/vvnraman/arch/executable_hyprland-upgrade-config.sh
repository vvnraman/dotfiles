#!/usr/bin/env bash
# vim: set ft=bash

# Assumptions
# - Version should be "major.minor", where both "major" and "minor" are integers
# - The version is written to the version file
# - `~/.config/hypr` should a symlink pointing to a versioned config directory
#   eg. for hyprland version "0.52.2-2", config would be at `~/.config/hypr_0.52`
# - If `~/.config/hypr` is not a symlink, or if the versioned config doesn't exist
#   then the script doesn't make any changes to the config dir.

CONFIG_PARENT="$HOME/.config"
CONFIG_FOLDER="hypr"
VERSION_FILE_PATH="$HOME/.config/vvnraman/arch/hyprland_version"
CHEZMOI_HYPR_PATH="$HOME/.local/share/chezmoi/home/dot_config/hypr"

function get_hyprland_version() {
  # shellcheck disable=SC2155
  local current_hyprland_version="$(pacman --query hyprland)"
  if [[ $? -ne 0 ]]; then
    exit 0
  fi

  # Only "major.minor" allowed
  HYPR_VERSION="$(echo "${current_hyprland_version}" | cut -d' ' -f2 | cut -d'.' -f1,2)"
  if [[ ! "${HYPR_VERSION}" =~ ^[0-9]+\.[0-9]+$ ]]; then
    exit 0
  fi
  printf "%s" "${HYPR_VERSION}"
}

function ensure_version_file_dir() {
  # shellcheck disable=SC2155
  local VERSION_FILE_DIR="$(dirname "${VERSION_FILE_PATH}")"
  if [[ ! -d "${VERSION_FILE_DIR}" ]]; then
    echo "'${VERSION_FILE_DIR}' does not exist"
    mkdir -p "${VERSION_FILE_DIR}"
    echo "'${VERSION_FILE_DIR}' created"
  fi
}

function ensure_symlink() {
  local file_path="$1"
  if [[ -e "${file_path}" ]]; then
    if [[ ! -L "${file_path}" ]]; then
      echo "'${file_path}' is not a symlink. Not proceeding further"
      exit 0
    else
      local symlink_dest
      symlink_dest="$(readlink "${file_path}")"
      echo "'${file_path}' is a symlink pointing to '${symlink_dest}'."
    fi
  else
    echo "'${file_path}' does not exist."
  fi
}

function ensure_chezmoi_template() {
  local file_path="$1"
  local template_path
  template_path="$(dirname "${file_path}")/symlink_$(basename "${file_path}").tmpl"
  if [[ ! -f "${template_path}" ]]; then
    echo "'${template_path}' for '${file_path}' does not exist. No proceeding further"
    exit 0
  else
    echo "'${template_path}' is a chezmoi template."
    if command -v chezmoi 1>/dev/null 2>&1; then
      local template_result
      template_result="$(chezmoi execute-template <"${template_path}" | tr -d \[:space:\])"
      echo "'${template_path}' evaluates to '${template_result}'"
    fi
  fi
}

function setup_config_symlink() {
  local version_folder="$1"
  local version_path="${CONFIG_PARENT}/${version_folder}"
  local canonical_path="${CONFIG_PARENT}/${CONFIG_FOLDER}"

  echo "Config parent dir = '${CONFIG_PARENT}'"
  echo "Config folder     = '${CONFIG_FOLDER}'"

  ensure_symlink "${canonical_path}"
  ensure_chezmoi_template "${CHEZMOI_HYPR_PATH}"

  # Update hyprland config symlink to the current version
  local existing_symlink_path
  existing_symlink_path="$(readlink -f "${canonical_path}")"
  if [[ "${version_path}" == "${existing_symlink_path}" ]]; then
    echo "Canonical config '${canonical_path}' already points to versioned config '${version_path}'. No-op."
    exit 0
  else
    echo "Canonical config '${canonical_path}' does not point to the current versioned config '${version_path}'."
    echo "Canonical config symlink    = '${canonical_path}'"
    echo "Config symlink points to    = '${existing_symlink_path}'"
    echo "Existing versioned config   = '${version_path}'"

    # push/popd keeps chezmoi semantics so that chezmoi status remains good.
    if [[ -L "${canonical_path}" ]]; then
      echo "Removing eixsting symlink at '${canonical_path}'"
      rm "${canonical_path}"
    fi
    echo "Creating symlink '${canonical_path}' to point to '${version_path}'"
    (cd "${CONFIG_PARENT}" && ln -s "${version_folder}" "${CONFIG_FOLDER}")
  fi
  exit 0
}

function suggest_follow_up_actions() {
  echo "All done. The following actions may need be to performed"
  echo "'hyprctl reload'  - Reload hyprland config to use the current versioned config"
  echo "'hyprpm update'   - Fetch and build plugin updates for the current version"
}

function main() {
  local hypr_version
  hypr_version="$(get_hyprland_version)"
  echo "Current hyprland version is '${hypr_version}'"

  # Update version file to be used by chezmoi
  ensure_version_file_dir
  echo "${hypr_version}" >"${VERSION_FILE_PATH}"

  local version_folder="${CONFIG_FOLDER}_${hypr_version}"

  # Stop if we do not have a versioned config directory
  if [[ ! -d "${CONFIG_PARENT}/${version_folder}" ]]; then
    echo "'${CONFIG_PARENT}/${version_folder}' does not exist. No-op."
    exit 0
  fi

  setup_config_symlink "${version_folder}"
  suggest_follow_up_actions
}

# disabled 2026-03-01
#main
