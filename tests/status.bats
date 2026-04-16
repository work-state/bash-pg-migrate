#!/usr/bin/env bats
# =============================================================================
# Tests: status command — show applied vs pending migrations
# =============================================================================

load 'helpers/common'

setup()    { setup_test_env; }
teardown() { teardown_test_env; }

# ---- No migration files -----------------------------------------------------

@test "status: no migration files shows empty notice" {
  run "${MIGRATE_SH}" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"No migration files found"* ]]
}

# ---- All applied ------------------------------------------------------------

@test "status: all applied migrations show check mark" {
  create_migration "20240101000000_create_users"
  create_migration "20240102000000_create_orders"
  export MOCK_APPLIED_MIGRATIONS="20240101000000_create_users.sql 20240102000000_create_orders.sql"
  run "${MIGRATE_SH}" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓"*"20240101000000_create_users.sql"* ]]
  [[ "$output" == *"✓"*"20240102000000_create_orders.sql"* ]]
}

# ---- All pending ------------------------------------------------------------

@test "status: all pending migrations show pending marker" {
  create_migration "20240101000000_create_users"
  create_migration "20240102000000_create_orders"
  run "${MIGRATE_SH}" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"20240101000000_create_users.sql"*"(pending)"* ]]
  [[ "$output" == *"20240102000000_create_orders.sql"*"(pending)"* ]]
}

# ---- Mixed ------------------------------------------------------------------

@test "status: applied and pending migrations shown correctly" {
  create_migration "20240101000000_create_users"
  create_migration "20240102000000_create_orders"
  export MOCK_APPLIED_MIGRATIONS="20240101000000_create_users.sql"
  run "${MIGRATE_SH}" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓"*"20240101000000_create_users.sql"* ]]
  [[ "$output" == *"20240102000000_create_orders.sql"*"(pending)"* ]]
}

# ---- Output structure -------------------------------------------------------

@test "status: output contains Migration Status header" {
  run "${MIGRATE_SH}" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Migration Status"* ]]
}
