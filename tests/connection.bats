#!/usr/bin/env bats
# =============================================================================
# Tests: database connection success and failure cases
# =============================================================================

load 'helpers/common'

setup()    { setup_test_env; }
teardown() { teardown_test_env; }

# ---- Successful connection --------------------------------------------------

@test "connection: successful connection prints connected message" {
  run "${MIGRATE_SH}" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Connected to"* ]]
}

@test "connection: successful connection shows host and database name" {
  run "${MIGRATE_SH}" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"localhost"* ]]
  [[ "$output" == *"testdb"* ]]
}

# ---- Database does not exist ------------------------------------------------

@test "connection: database not found exits with error" {
  export MOCK_DB_EXISTS=0
  run "${MIGRATE_SH}" status
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "connection: database not found names the missing database" {
  export MOCK_DB_EXISTS=0
  run "${MIGRATE_SH}" status
  [ "$status" -eq 1 ]
  [[ "$output" == *"testdb"* ]]
}

# ---- Connection refused -----------------------------------------------------

@test "connection: refused connection exits with error" {
  export MOCK_CONN_FAIL=1
  run "${MIGRATE_SH}" status
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not connect"* ]]
}

@test "connection: refused connection names the host and user" {
  export MOCK_CONN_FAIL=1
  run "${MIGRATE_SH}" status
  [ "$status" -eq 1 ]
  [[ "$output" == *"localhost"* ]]
  [[ "$output" == *"postgres"* ]]
}

# ---- Migrations table creation failure --------------------------------------

@test "connection: _migrations table creation failure exits with error" {
  export MOCK_ENSURE_TABLE_FAIL=1
  run "${MIGRATE_SH}" status
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to create _migrations table"* ]]
}

@test "connection: _migrations table failure shows GRANT hint" {
  export MOCK_ENSURE_TABLE_FAIL=1
  run "${MIGRATE_SH}" status
  [ "$status" -eq 1 ]
  [[ "$output" == *"GRANT CREATE ON SCHEMA"* ]]
}
