# =============================================================================
# Shared test utilities for install.sh tests
# Loaded by test/install.bats via: load 'helpers/install_common'
# =============================================================================

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALL_SH="${REPO_DIR}/install.sh"
MOCKS_INSTALL_DIR="${REPO_DIR}/test/mocks/install"

# ---- Setup / Teardown -------------------------------------------------------

# All three mocks (uname, psql, pg_dump) are copied from test/mocks/install/
# into a fresh per-test directory (INSTALL_MOCKS). This means:
#   - Tests that need "missing psql" just rm "${INSTALL_MOCKS}/psql" before run.
#   - No mock bleeds from one test to the next.
#   - test/mocks/install/ stays flat — no templates/ subdirectory needed.
setup_install_env() {
  INSTALL_TEST_PREFIX="$(mktemp -d)"
  INSTALL_MOCKS="$(mktemp -d)"
  mkdir -p "${INSTALL_TEST_PREFIX}/bin"

  cp "${MOCKS_INSTALL_DIR}/uname"   "${INSTALL_MOCKS}/uname"
  cp "${MOCKS_INSTALL_DIR}/psql"    "${INSTALL_MOCKS}/psql"
  cp "${MOCKS_INSTALL_DIR}/pg_dump" "${INSTALL_MOCKS}/pg_dump"
  chmod +x "${INSTALL_MOCKS}/uname" "${INSTALL_MOCKS}/psql" "${INSTALL_MOCKS}/pg_dump"

  # Minimal system PATH: INSTALL_MOCKS covers all mocks; /usr/bin and /bin
  # cover the POSIX utilities (mkdir, cp, chmod, rm, grep) that install.sh needs.
  export PATH="${INSTALL_MOCKS}:/usr/bin:/bin"

  # Default OS for tests — override with: export MOCK_OS="linux" etc.
  export MOCK_OS="macos"
}

teardown_install_env() {
  if [[ -n "${INSTALL_TEST_PREFIX:-}" && -d "${INSTALL_TEST_PREFIX}" ]]; then
    chmod -R u+w "${INSTALL_TEST_PREFIX}" 2>/dev/null || true
    rm -rf "${INSTALL_TEST_PREFIX}"
  fi
  if [[ -n "${INSTALL_MOCKS:-}" && -d "${INSTALL_MOCKS}" ]]; then
    rm -rf "${INSTALL_MOCKS}"
  fi
  unset INSTALL_TEST_PREFIX INSTALL_MOCKS MOCK_OS
}
