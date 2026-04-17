#!/usr/bin/env bats
# =============================================================================
# Tests: snapshot command — per-table schema dump
# =============================================================================

load 'helpers/common'

setup()    { setup_test_env; }
teardown() { teardown_test_env; }

# ---- pg_dump not installed --------------------------------------------------

@test "snapshot: pg_dump not installed exits with error" {
  # Build a PATH that has mock psql but no pg_dump
  local tmp_bin
  tmp_bin="$(mktemp -d)"
  cp "${MOCKS_MIGRATE_DIR}/psql" "${tmp_bin}/psql"
  chmod +x "${tmp_bin}/psql"
  export PATH="${tmp_bin}:/usr/bin:/bin"

  run "${MIGRATE_SH}" snapshot
  rm -rf "$tmp_bin"
  [ "$status" -eq 1 ]
  [[ "$output" == *"pg_dump is not installed"* ]]
}

# ---- No tables --------------------------------------------------------------

@test "snapshot: no tables in schema skips generation" {
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  [[ "$output" == *"No tables found"* ]]
}

# ---- Successful generation --------------------------------------------------

@test "snapshot: generates one file per table" {
  export MOCK_TABLES="users orders"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  [ -f "${TEST_PROJECT_DIR}/schemas/users.sql" ]
  [ -f "${TEST_PROJECT_DIR}/schemas/orders.sql" ]
}

@test "snapshot: snapshot file contains table name in header" {
  export MOCK_TABLES="users"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  grep -q "users" "${TEST_PROJECT_DIR}/schemas/users.sql"
}

@test "snapshot: snapshot file contains DO NOT EXECUTE warning" {
  export MOCK_TABLES="users"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  grep -q "DO NOT EXECUTE" "${TEST_PROJECT_DIR}/schemas/users.sql"
}

@test "snapshot: snapshot file contains auto-generated notice" {
  export MOCK_TABLES="users"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  grep -q "Auto-generated snapshot" "${TEST_PROJECT_DIR}/schemas/users.sql"
}

@test "snapshot: snapshot file contains CREATE TABLE statement" {
  export MOCK_TABLES="users"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  grep -q "CREATE TABLE" "${TEST_PROJECT_DIR}/schemas/users.sql"
}

@test "snapshot: snapshot file does not contain SET statements" {
  export MOCK_TABLES="users"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  ! grep -q "^SET " "${TEST_PROJECT_DIR}/schemas/users.sql"
}

@test "snapshot: snapshot file does not contain pg_dump comment lines" {
  export MOCK_TABLES="users"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  # pg_dump emits "-- Name: ...; Type: ..." style comments — sed filter must strip them
  ! grep -qE "^-- Name:.*Type:" "${TEST_PROJECT_DIR}/schemas/users.sql"
}

@test "snapshot: snapshot file does not contain SET statements from pg_dump" {
  export MOCK_TABLES="users"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  ! grep -qE "^SET " "${TEST_PROJECT_DIR}/schemas/users.sql"
}

@test "snapshot: prints success message per table" {
  export MOCK_TABLES="users orders"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  [[ "$output" == *"Snapshot:"*"users.sql"* ]]
  [[ "$output" == *"Snapshot:"*"orders.sql"* ]]
}

@test "snapshot: creates schemas directory if it does not exist" {
  rmdir "${TEST_PROJECT_DIR}/schemas"
  export MOCK_TABLES="users"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  [ -d "${TEST_PROJECT_DIR}/schemas" ]
}
