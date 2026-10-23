#!/usr/bin/env bats
# =============================================================================
# Tests: --version command — read the current release from VERSION.md
# =============================================================================

load 'helpers/common'

setup()    { setup_test_env; }
teardown() {
  if [[ -n "${VERSION_TEST_DIR:-}" && -d "$VERSION_TEST_DIR" ]]; then
    rm -rf "$VERSION_TEST_DIR"
  fi
  teardown_test_env
}

# Copy migrate.sh and its libs into a temp dir so VERSION.md can be swapped
# Usage: setup_version_copy [version_md_contents]
setup_version_copy() {
  VERSION_TEST_DIR="$(mktemp -d)"
  cp "${MIGRATE_SH}" "${VERSION_TEST_DIR}/migrate.sh"
  cp -R "${REPO_DIR}/lib" "${REPO_DIR}/cmd" "${VERSION_TEST_DIR}/"
  if [[ $# -gt 0 ]]; then
    printf '%s\n' "$1" > "${VERSION_TEST_DIR}/VERSION.md"
  fi
}

# ---- Output -----------------------------------------------------------------

@test "version: --version exits with status 0" {
  run "${MIGRATE_SH}" --version
  [ "$status" -eq 0 ]
}

@test "version: --version prints the first version in VERSION.md" {
  local expected
  expected=$(awk -F'|' '$2 ~ /^ *[0-9]+\.[0-9]+\.[0-9]+ *$/ { gsub(/ /, "", $2); print $2; exit }' "${REPO_DIR}/VERSION.md")
  run "${MIGRATE_SH}" --version
  [ "$output" = "pgmigrate ${expected}" ]
}

@test "version: -v is an alias for --version" {
  run "${MIGRATE_SH}" -v
  [ "$status" -eq 0 ]
  [[ "$output" == "pgmigrate "* ]]
}

@test "version: picks the top row when several versions are listed" {
  setup_version_copy "| Version | Date | Summary | Details |
|---------|------|---------|---------|
| 2.3.4   | 2026-12-01 | Newer | x |
| 1.0.0   | 2026-06-11 | Older | x |"
  run "${VERSION_TEST_DIR}/migrate.sh" --version
  [ "$status" -eq 0 ]
  [ "$output" = "pgmigrate 2.3.4" ]
}

@test "version: works without a .env file" {
  rm "${TEST_PROJECT_DIR}/.env"
  run "${MIGRATE_SH}" --version
  [ "$status" -eq 0 ]
  [[ "$output" == "pgmigrate "* ]]
}

# ---- Errors -----------------------------------------------------------------

@test "version: missing VERSION.md exits with error" {
  setup_version_copy
  run "${VERSION_TEST_DIR}/migrate.sh" --version
  [ "$status" -eq 1 ]
  [[ "$output" == *"VERSION.md not found"* ]]
}

@test "version: VERSION.md without a version row exits with error" {
  setup_version_copy "# Versions"
  run "${VERSION_TEST_DIR}/migrate.sh" --version
  [ "$status" -eq 1 ]
  [[ "$output" == *"No version found"* ]]
}

@test "help: lists the --version option" {
  run "${MIGRATE_SH}" help
  [[ "$output" == *"--version"* ]]
}
