# =============================================================================
# Shared test utilities for migrate.sh tests
# Loaded by every .bats file via: load 'helpers/common'
# =============================================================================

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATE_SH="${REPO_DIR}/migrate.sh"

# ---- Setup / Teardown -------------------------------------------------------

# Call in bats setup() — creates an isolated temp project directory
setup_test_env() {
  TEST_PROJECT_DIR="$(mktemp -d)"
  export PGMIGRATE_PROJECT_DIR="${TEST_PROJECT_DIR}"
  export PATH="${HELPERS_DIR}:${PATH}"

  mkdir -p "${TEST_PROJECT_DIR}/migrations"
  mkdir -p "${TEST_PROJECT_DIR}/schemas"

  write_default_env
}

# Call in bats teardown() — removes temp directory and resets all mock vars
teardown_test_env() {
  # Guard against accidental rm -rf "" if TEST_PROJECT_DIR is somehow unset
  if [[ -n "${TEST_PROJECT_DIR:-}" && -d "$TEST_PROJECT_DIR" ]]; then
    rm -rf "$TEST_PROJECT_DIR"
  fi
  unset TEST_PROJECT_DIR PGMIGRATE_PROJECT_DIR
  unset MOCK_PSQL_FAIL MOCK_CONN_FAIL MOCK_DB_EXISTS
  unset MOCK_ENSURE_TABLE_FAIL MOCK_SQL_EXEC_FAIL
  unset MOCK_TABLES MOCK_APPLIED_MIGRATIONS MOCK_CHECKSUM
  unset MOCK_LAST_MIGRATION MOCK_PG_DUMP_FAIL
}

# ---- Helpers ----------------------------------------------------------------

write_default_env() {
  cat > "${TEST_PROJECT_DIR}/.env" <<EOF
DB_HOST=localhost
DB_PORT=5432
DB_NAME=testdb
DB_USER=postgres
DB_PASSWORD=secret
EOF
}

# Create a migration file under the test project's migrations/ directory
# Usage: create_migration <filename_without_ext> [up_sql] [down_sql]
create_migration() {
  local filename="$1"
  local up_sql="${2:-CREATE TABLE test_table (id SERIAL PRIMARY KEY);}"
  local down_sql="${3:-DROP TABLE IF EXISTS test_table;}"

  cat > "${TEST_PROJECT_DIR}/migrations/${filename}.sql" <<EOF
-- UP
${up_sql}

-- DOWN
${down_sql}
EOF
}
