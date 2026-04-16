#!/usr/bin/env bats
# =============================================================================
# Tests: create command — scaffold a new migration file
# =============================================================================

load 'helpers/common'

setup()    { setup_test_env; }
teardown() { teardown_test_env; }

# ---- Missing name argument --------------------------------------------------

@test "create: missing name argument exits with error" {
  run "${MIGRATE_SH}" create
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "create: missing name shows example usage" {
  run "${MIGRATE_SH}" create
  [ "$status" -eq 1 ]
  [[ "$output" == *"create_users_table"* ]]
}

# ---- Successful creation ----------------------------------------------------

@test "create: creates a file in migrations directory" {
  run "${MIGRATE_SH}" create add_users_table
  [ "$status" -eq 0 ]
  local count
  count=$(ls "${TEST_PROJECT_DIR}/migrations/"*.sql 2>/dev/null | wc -l | tr -d ' ')
  [ "$count" -eq 1 ]
}

@test "create: filename contains the provided name" {
  run "${MIGRATE_SH}" create add_users_table
  [ "$status" -eq 0 ]
  ls "${TEST_PROJECT_DIR}/migrations/"*add_users_table.sql
}

@test "create: filename starts with a timestamp prefix" {
  run "${MIGRATE_SH}" create add_users_table
  [ "$status" -eq 0 ]
  local filename
  filename=$(basename "${TEST_PROJECT_DIR}/migrations/"*.sql)
  [[ "$filename" =~ ^[0-9]{14}_add_users_table\.sql$ ]]
}

@test "create: generated file contains -- UP marker" {
  run "${MIGRATE_SH}" create add_users_table
  [ "$status" -eq 0 ]
  local file
  file="${TEST_PROJECT_DIR}/migrations/"*.sql
  grep -q "^-- UP$" $file
}

@test "create: generated file contains -- DOWN marker" {
  run "${MIGRATE_SH}" create add_users_table
  [ "$status" -eq 0 ]
  local file
  file="${TEST_PROJECT_DIR}/migrations/"*.sql
  grep -q "^-- DOWN$" $file
}

@test "create: -- UP appears before -- DOWN in generated file" {
  run "${MIGRATE_SH}" create add_users_table
  [ "$status" -eq 0 ]
  local file up_line down_line
  file=$(ls "${TEST_PROJECT_DIR}/migrations/"*.sql)
  up_line=$(grep -n "^-- UP$" "$file" | cut -d: -f1)
  down_line=$(grep -n "^-- DOWN$" "$file" | cut -d: -f1)
  [ "$up_line" -lt "$down_line" ]
}

@test "create: creates migrations directory if it does not exist" {
  rmdir "${TEST_PROJECT_DIR}/migrations"
  run "${MIGRATE_SH}" create add_users_table
  [ "$status" -eq 0 ]
  [ -d "${TEST_PROJECT_DIR}/migrations" ]
}

@test "create: prints success message with filename" {
  run "${MIGRATE_SH}" create add_users_table
  [ "$status" -eq 0 ]
  [[ "$output" == *"Created:"* ]]
  [[ "$output" == *"add_users_table.sql"* ]]
}
