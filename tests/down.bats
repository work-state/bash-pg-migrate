#!/usr/bin/env bats
# =============================================================================
# Tests: down command — rollback the last applied migration
# =============================================================================

load 'helpers/common'

setup()    { setup_test_env; }
teardown() { teardown_test_env; }

# ---- Nothing to rollback ----------------------------------------------------

@test "down: no applied migrations shows info message" {
  run "${MIGRATE_SH}" down
  [ "$status" -eq 0 ]
  [[ "$output" == *"No migrations to rollback"* ]]
}

# ---- Successful rollback ----------------------------------------------------

@test "down: rolls back the last applied migration" {
  create_migration "20240101000000_create_users"
  export MOCK_LAST_MIGRATION="20240101000000_create_users.sql"
  run "${MIGRATE_SH}" down
  [ "$status" -eq 0 ]
  [[ "$output" == *"Rolled back: 20240101000000_create_users.sql"* ]]
}

@test "down: triggers snapshot after successful rollback" {
  create_migration "20240101000000_create_users"
  export MOCK_LAST_MIGRATION="20240101000000_create_users.sql"
  export MOCK_TABLES="orders"
  run "${MIGRATE_SH}" down
  [ "$status" -eq 0 ]
  [[ "$output" == *"Snapshot:"* ]]
}

# ---- Migration file not found -----------------------------------------------

@test "down: missing migration file exits with error" {
  # _migrations reports a file that doesn't exist on disk
  export MOCK_LAST_MIGRATION="20240101000000_missing.sql"
  run "${MIGRATE_SH}" down
  [ "$status" -eq 1 ]
  [[ "$output" == *"Migration file not found"* ]]
}

@test "down: missing file error names the file" {
  export MOCK_LAST_MIGRATION="20240101000000_missing.sql"
  run "${MIGRATE_SH}" down
  [ "$status" -eq 1 ]
  [[ "$output" == *"20240101000000_missing.sql"* ]]
}

# ---- Missing DOWN section ---------------------------------------------------

@test "down: missing -- DOWN section exits with error" {
  cat > "${TEST_PROJECT_DIR}/migrations/20240101000000_bad.sql" <<'EOF'
-- UP
CREATE TABLE bad (id SERIAL PRIMARY KEY);
EOF
  export MOCK_LAST_MIGRATION="20240101000000_bad.sql"
  run "${MIGRATE_SH}" down
  [ "$status" -eq 1 ]
  [[ "$output" == *"No -- DOWN section"* ]]
}

# ---- SQL execution failure --------------------------------------------------

@test "down: SQL execution failure exits with error" {
  create_migration "20240101000000_create_users"
  export MOCK_LAST_MIGRATION="20240101000000_create_users.sql"
  export MOCK_SQL_EXEC_FAIL=1
  run "${MIGRATE_SH}" down
  [ "$status" -eq 1 ]
}
