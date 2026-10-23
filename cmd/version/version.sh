#!/usr/bin/env bash
# =============================================================================
# Command: version — print the installed version from VERSION.md
# =============================================================================

# The first row of the "Released versions" table is the current release
cmd_version() {
  local version_file="${SCRIPT_DIR}/VERSION.md"
  local version

  if [[ ! -f "$version_file" ]]; then
    log_error "VERSION.md not found in ${SCRIPT_DIR}"
    exit 1
  fi

  version=$(awk -F'|' '$2 ~ /^ *[0-9]+\.[0-9]+\.[0-9]+ *$/ { gsub(/ /, "", $2); print $2; exit }' "$version_file")

  if [[ -z "$version" ]]; then
    log_error "No version found in ${version_file}"
    exit 1
  fi

  echo "pgmigrate ${version}"
}
