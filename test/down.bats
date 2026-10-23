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

# ---- Step count: down N -----------------------------------------------------

@test "down: N rolls back the last N migrations, newest first" {
  create_migration "20240101000000_create_users"
  create_migration "20240102000000_create_orders"
  create_migration "20240103000000_create_products"
  export MOCK_APPLIED_MIGRATIONS="20240101000000_create_users.sql 20240102000000_create_orders.sql 20240103000000_create_products.sql"
  run "${MIGRATE_SH}" down 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"Rolled back: 20240103000000_create_products.sql"*"Rolled back: 20240102000000_create_orders.sql"* ]]
  [[ "$output" != *"20240101000000_create_users.sql"* ]]
  [[ "$output" == *"Rolled back 2 migration(s)."* ]]
}

@test "down: without N rolls back only the last migration" {
  create_migration "20240101000000_create_users"
  create_migration "20240102000000_create_orders"
  export MOCK_APPLIED_MIGRATIONS="20240101000000_create_users.sql 20240102000000_create_orders.sql"
  run "${MIGRATE_SH}" down
  [ "$status" -eq 0 ]
  [[ "$output" == *"Rolled back: 20240102000000_create_orders.sql"* ]]
  [[ "$output" != *"20240101000000_create_users.sql"* ]]
}

@test "down: N larger than the applied count rolls back all of them" {
  create_migration "20240101000000_create_users"
  create_migration "20240102000000_create_orders"
  export MOCK_APPLIED_MIGRATIONS="20240101000000_create_users.sql 20240102000000_create_orders.sql"
  run "${MIGRATE_SH}" down 5
  [ "$status" -eq 0 ]
  [[ "$output" == *"Only 2 migration(s) were applied"* ]]
  [[ "$output" == *"Rolled back 2 migration(s)."* ]]
}

@test "down: N with a missing file rolls back nothing" {
  create_migration "20240101000000_create_users"
  export MOCK_APPLIED_MIGRATIONS="20240101000000_create_users.sql 20240102000000_missing.sql"
  run "${MIGRATE_SH}" down 2
  [ "$status" -eq 1 ]
  [[ "$output" == *"Migration file not found"*"20240102000000_missing.sql"* ]]
  [[ "$output" != *"Rolling back"* ]]
}

@test "down: N with a missing DOWN section rolls back nothing" {
  create_migration "20240101000000_create_users"
  cat > "${TEST_PROJECT_DIR}/migrations/20240102000000_bad.sql" <<'SQL'
-- UP
CREATE TABLE bad (id SERIAL PRIMARY KEY);
SQL
  export MOCK_APPLIED_MIGRATIONS="20240101000000_create_users.sql 20240102000000_bad.sql"
  run "${MIGRATE_SH}" down 2
  [ "$status" -eq 1 ]
  [[ "$output" == *"No -- DOWN section found in 20240102000000_bad.sql"* ]]
  [[ "$output" != *"Rolling back"* ]]
}

@test "down: rejects a step count that is not a positive whole number" {
  local count
  for count in 0 -1 abc 1.5; do
    run "${MIGRATE_SH}" down "$count"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: ./migrate.sh down [N]"* ]]
  done
}

# ---- Failure reporting ------------------------------------------------------

@test "down: SQL failure prints which rollback failed" {
  create_migration "20240101000000_create_users"
  export MOCK_LAST_MIGRATION="20240101000000_create_users.sql"
  export MOCK_SQL_EXEC_FAIL=1
  run "${MIGRATE_SH}" down
  [ "$status" -eq 1 ]
  [[ "$output" == *"Rollback failed: 20240101000000_create_users.sql"* ]]
}
