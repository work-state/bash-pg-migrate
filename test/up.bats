#!/usr/bin/env bats
# =============================================================================
# Tests: up command — apply pending migrations
# =============================================================================

load 'helpers/common'

setup()    { setup_test_env; }
teardown() { teardown_test_env; }

# ---- No migrations ----------------------------------------------------------

@test "up: no migrations directory shows warning" {
  rmdir "${TEST_PROJECT_DIR}/migrations"
  run "${MIGRATE_SH}" up
  [ "$status" -eq 0 ]
  [[ "$output" == *"No migrations directory"* ]]
}

@test "up: no pending migrations shows info message" {
  create_migration "20240101000000_create_users"
  export MOCK_APPLIED_MIGRATIONS="20240101000000_create_users.sql"
  run "${MIGRATE_SH}" up
  [ "$status" -eq 0 ]
  [[ "$output" == *"No pending migrations"* ]]
}

# ---- Successful apply -------------------------------------------------------

@test "up: applies a single pending migration" {
  create_migration "20240101000000_create_users"
  run "${MIGRATE_SH}" up
  [ "$status" -eq 0 ]
  [[ "$output" == *"Applied: 20240101000000_create_users.sql"* ]]
}

@test "up: reports applied count after success" {
  create_migration "20240101000000_create_users"
  create_migration "20240102000000_create_orders"
  run "${MIGRATE_SH}" up
  [ "$status" -eq 0 ]
  [[ "$output" == *"Applied 2 migration(s)"* ]]
}

@test "up: skips already applied migrations" {
  create_migration "20240101000000_create_users"
  create_migration "20240102000000_create_orders"
  export MOCK_APPLIED_MIGRATIONS="20240101000000_create_users.sql"
  run "${MIGRATE_SH}" up
  [ "$status" -eq 0 ]
  [[ "$output" == *"Applied: 20240102000000_create_orders.sql"* ]]
  [[ "$output" != *"Applied: 20240101000000_create_users.sql"* ]]
}

@test "up: triggers snapshot after successful apply" {
  create_migration "20240101000000_create_users"
  export MOCK_TABLES="users"
  run "${MIGRATE_SH}" up
  [ "$status" -eq 0 ]
  [[ "$output" == *"Snapshot:"* ]]
}

# ---- Checksum mismatch ------------------------------------------------------

@test "up: checksum mismatch exits with error" {
  create_migration "20240101000000_create_users"
  export MOCK_APPLIED_MIGRATIONS="20240101000000_create_users.sql"
  export MOCK_CHECKSUM="0000000000000000000000000000000000000000000000000000000000000000"
  run "${MIGRATE_SH}" up
  [ "$status" -eq 1 ]
  [[ "$output" == *"Checksum mismatch"* ]]
}

@test "up: checksum mismatch names the offending file" {
  create_migration "20240101000000_create_users"
  export MOCK_APPLIED_MIGRATIONS="20240101000000_create_users.sql"
  export MOCK_CHECKSUM="0000000000000000000000000000000000000000000000000000000000000000"
  run "${MIGRATE_SH}" up
  [ "$status" -eq 1 ]
  [[ "$output" == *"20240101000000_create_users.sql"* ]]
}

# ---- Missing UP section -----------------------------------------------------

@test "up: missing -- UP section exits with error" {
  cat > "${TEST_PROJECT_DIR}/migrations/20240101000000_bad.sql" <<'EOF'
-- DOWN
DROP TABLE IF EXISTS bad;
EOF
  run "${MIGRATE_SH}" up
  [ "$status" -eq 1 ]
  [[ "$output" == *"No -- UP section"* ]]
}

# ---- SQL execution failure --------------------------------------------------

@test "up: SQL execution failure exits with error" {
  create_migration "20240101000000_create_users"
  export MOCK_SQL_EXEC_FAIL=1
  run "${MIGRATE_SH}" up
  [ "$status" -eq 1 ]
}

# ---- Step count: up N -------------------------------------------------------

@test "up: N applies only the next N pending migrations" {
  create_migration "20240101000000_create_users"
  create_migration "20240102000000_create_orders"
  create_migration "20240103000000_create_products"
  run "${MIGRATE_SH}" up 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"Applied: 20240101000000_create_users.sql"* ]]
  [[ "$output" == *"Applied: 20240102000000_create_orders.sql"* ]]
  [[ "$output" != *"20240103000000_create_products.sql"* ]]
  [[ "$output" == *"Applied 2 migration(s)."* ]]
}

@test "up: 1 applies the pending migration right after the applied ones" {
  create_migration "20240101000000_create_users"
  create_migration "20240102000000_create_orders"
  create_migration "20240103000000_create_products"
  export MOCK_APPLIED_MIGRATIONS="20240101000000_create_users.sql"
  run "${MIGRATE_SH}" up 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Applied: 20240102000000_create_orders.sql"* ]]
  [[ "$output" != *"20240103000000_create_products.sql"* ]]
}

@test "up: N larger than the pending count applies all of them" {
  create_migration "20240101000000_create_users"
  create_migration "20240102000000_create_orders"
  run "${MIGRATE_SH}" up 10
  [ "$status" -eq 0 ]
  [[ "$output" == *"Applied 2 migration(s)."* ]]
}

@test "up: N still verifies checksums of applied migrations after the limit" {
  create_migration "20240101000000_create_users"
  create_migration "20240102000000_create_orders"
  export MOCK_APPLIED_MIGRATIONS="20240102000000_create_orders.sql"
  export MOCK_CHECKSUM="0000000000000000000000000000000000000000000000000000000000000000"
  run "${MIGRATE_SH}" up 1
  [ "$status" -eq 1 ]
  [[ "$output" == *"Checksum mismatch: 20240102000000_create_orders.sql"* ]]
}

@test "up: rejects a step count that is not a positive whole number" {
  local count
  for count in 0 -1 abc 1.5; do
    run "${MIGRATE_SH}" up "$count"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: ./migrate.sh up [N]"* ]]
  done
}

@test "up: rejects more than one argument" {
  run "${MIGRATE_SH}" up 1 2
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage: ./migrate.sh up [N]"* ]]
}

# ---- Failure reporting ------------------------------------------------------

@test "up: SQL failure prints which migration failed" {
  create_migration "20240101000000_create_users"
  export MOCK_SQL_EXEC_FAIL=1
  run "${MIGRATE_SH}" up
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed: 20240101000000_create_users.sql"* ]]
}
