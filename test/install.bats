#!/usr/bin/env bats
# =============================================================================
# Tests: install.sh — argument parsing, OS detection, dependency checks,
#                     install, uninstall, and launcher self-removal
#
# Notes:
#   - WSL is not tested independently: its detect_os() branch relies on
#     /proc/version which does not exist on macOS. WSL follows the same
#     install_linux() path so it is implicitly covered by the Linux tests.
#   - check_bash_version_macos() uses BASH_VERSINFO which is a readonly
#     shell builtin and cannot be mocked. It only warns (never exits), so
#     it is implicitly covered by every macOS install test succeeding.
# =============================================================================

load 'helpers/install_common'

setup()    { setup_install_env; }
teardown() { teardown_install_env; }

# ---- Argument parsing -------------------------------------------------------

@test "install: --help exits with status 0" {
  run "${INSTALL_SH}" --help
  [ "$status" -eq 0 ]
}

@test "install: --help shows usage" {
  run "${INSTALL_SH}" --help
  [[ "$output" == *"Usage"* ]]
}

@test "install: unknown option exits with error" {
  run "${INSTALL_SH}" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

@test "install: --prefix installs to the given directory" {
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  [ "$status" -eq 0 ]
  [ -f "${INSTALL_TEST_PREFIX}/bin/pgmigrate" ]
}

# ---- OS blocking ------------------------------------------------------------

@test "install: Windows exits with error" {
  export MOCK_OS="windows"
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not supported"* ]]
}

@test "install: Windows shows WSL as the alternative" {
  export MOCK_OS="windows"
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"WSL"* ]]
}

@test "install: unsupported OS exits with error" {
  export MOCK_OS="unsupported"
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unsupported"* ]]
}

# ---- Dependency checks — macOS ----------------------------------------------

@test "install: macOS all dependencies present shows success" {
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"All dependencies found"* ]]
}

@test "install: macOS missing psql shows warning" {
  rm "${INSTALL_MOCKS}/psql"
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Missing dependencies"* ]]
}

@test "install: macOS missing psql shows brew install hint" {
  rm "${INSTALL_MOCKS}/psql"
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"brew install postgresql"* ]]
}

@test "install: macOS missing pg_dump shows warning" {
  rm "${INSTALL_MOCKS}/pg_dump"
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Missing dependencies"* ]]
}

# ---- Dependency checks — Linux ----------------------------------------------

@test "install: Linux all dependencies present shows success" {
  export MOCK_OS="linux"
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"All dependencies found"* ]]
}

@test "install: Linux missing deps shows apt-get install hint" {
  export MOCK_OS="linux"
  rm "${INSTALL_MOCKS}/psql"
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"apt-get install postgresql-client"* ]]
}

# ---- Full install — file layout ---------------------------------------------

@test "install: copies migrate.sh to LIB_DIR" {
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  [ "$status" -eq 0 ]
  [ -f "${INSTALL_TEST_PREFIX}/lib/pgmigrate/migrate.sh" ]
}

@test "install: copies lib/helpers scripts to LIB_DIR" {
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  [ "$status" -eq 0 ]
  [ -f "${INSTALL_TEST_PREFIX}/lib/pgmigrate/lib/helpers/constants.sh" ]
  [ -f "${INSTALL_TEST_PREFIX}/lib/pgmigrate/lib/helpers/helpers.sh" ]
  [ -f "${INSTALL_TEST_PREFIX}/lib/pgmigrate/lib/helpers/db.sh" ]
  [ -f "${INSTALL_TEST_PREFIX}/lib/pgmigrate/lib/helpers/snapshot.sh" ]
}

@test "install: copies all cmd scripts to LIB_DIR" {
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  [ "$status" -eq 0 ]
  [ -f "${INSTALL_TEST_PREFIX}/lib/pgmigrate/cmd/up/up.sh" ]
  [ -f "${INSTALL_TEST_PREFIX}/lib/pgmigrate/cmd/down/down.sh" ]
  [ -f "${INSTALL_TEST_PREFIX}/lib/pgmigrate/cmd/status/status.sh" ]
  [ -f "${INSTALL_TEST_PREFIX}/lib/pgmigrate/cmd/create/create.sh" ]
  [ -f "${INSTALL_TEST_PREFIX}/lib/pgmigrate/cmd/snapshot/snapshot.sh" ]
  [ -f "${INSTALL_TEST_PREFIX}/lib/pgmigrate/cmd/help/help.sh" ]
}

@test "install: migrate.sh is executable after install" {
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  [ "$status" -eq 0 ]
  [ -x "${INSTALL_TEST_PREFIX}/lib/pgmigrate/migrate.sh" ]
}

@test "install: launcher is copied to bin/" {
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  [ "$status" -eq 0 ]
  [ -f "${INSTALL_TEST_PREFIX}/bin/pgmigrate" ]
}

@test "install: launcher is executable" {
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  [ "$status" -eq 0 ]
  [ -x "${INSTALL_TEST_PREFIX}/bin/pgmigrate" ]
}

@test "install: prints success message" {
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed successfully"* ]]
}

@test "install: Linux install shows Linux banner" {
  export MOCK_OS="linux"
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing pgmigrate on Linux"* ]]
}

# ---- Install failures -------------------------------------------------------

@test "install: missing bin directory exits with error" {
  rmdir "${INSTALL_TEST_PREFIX}/bin"
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "install: unwritable bin directory exits with error" {
  chmod 555 "${INSTALL_TEST_PREFIX}/bin"
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No write permission"* ]]
}

@test "install: unwritable bin directory shows sudo hint" {
  chmod 555 "${INSTALL_TEST_PREFIX}/bin"
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"sudo"* ]]
}

# ---- Uninstall via --uninstall flag -----------------------------------------

@test "uninstall: removes LIB_DIR" {
  "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}" --uninstall
  [ "$status" -eq 0 ]
  [ ! -d "${INSTALL_TEST_PREFIX}/lib/pgmigrate" ]
}

@test "uninstall: removes BIN_FILE" {
  "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}" --uninstall
  [ "$status" -eq 0 ]
  [ ! -f "${INSTALL_TEST_PREFIX}/bin/pgmigrate" ]
}

@test "uninstall: prints success message" {
  "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}" --uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"uninstalled"* ]]
}

@test "uninstall: LIB_DIR already absent shows warning and continues" {
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}" --uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "uninstall: BIN_FILE already absent shows warning and continues" {
  mkdir -p "${INSTALL_TEST_PREFIX}/lib/pgmigrate"
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}" --uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "uninstall: unwritable LIB_DIR exits with error" {
  "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  chmod 555 "${INSTALL_TEST_PREFIX}/lib/pgmigrate"
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}" --uninstall
  [ "$status" -eq 1 ]
  [[ "$output" == *"No write permission"* ]]
}

@test "uninstall: unwritable BIN_FILE exits with error" {
  "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  chmod 444 "${INSTALL_TEST_PREFIX}/bin/pgmigrate"
  run "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}" --uninstall
  [ "$status" -eq 1 ]
  [[ "$output" == *"No write permission"* ]]
}

# ---- Launcher self-uninstall ------------------------------------------------

@test "launcher: uninstall subcommand removes LIB_DIR" {
  "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  run "${INSTALL_TEST_PREFIX}/bin/pgmigrate" uninstall
  [ "$status" -eq 0 ]
  [ ! -d "${INSTALL_TEST_PREFIX}/lib/pgmigrate" ]
}

@test "launcher: uninstall subcommand removes BIN_FILE" {
  "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  run "${INSTALL_TEST_PREFIX}/bin/pgmigrate" uninstall
  [ "$status" -eq 0 ]
  [ ! -f "${INSTALL_TEST_PREFIX}/bin/pgmigrate" ]
}

@test "launcher: uninstall prints success message" {
  "${INSTALL_SH}" --prefix "${INSTALL_TEST_PREFIX}"
  run "${INSTALL_TEST_PREFIX}/bin/pgmigrate" uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"uninstalled"* ]]
}
