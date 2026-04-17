#!/usr/bin/env bats
# =============================================================================
# Tests: .env loading and environment variable validation
# =============================================================================

load 'helpers/common'

setup()    { setup_test_env; }
teardown() { teardown_test_env; }

# ---- Missing .env file ------------------------------------------------------

@test "env: missing .env exits with error" {
  rm "${TEST_PROJECT_DIR}/.env"
  run "${MIGRATE_SH}" status
  [ "$status" -eq 1 ]
  [[ "$output" == *".env file not found"* ]]
}

# ---- Missing required variables ---------------------------------------------

@test "env: missing DB_HOST exits with error" {
  printf 'DB_PORT=5432\nDB_NAME=testdb\nDB_USER=postgres\nDB_PASSWORD=secret\n' \
    > "${TEST_PROJECT_DIR}/.env"
  run "${MIGRATE_SH}" status
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing required variable: DB_HOST"* ]]
}

@test "env: missing DB_PORT exits with error" {
  printf 'DB_HOST=localhost\nDB_NAME=testdb\nDB_USER=postgres\nDB_PASSWORD=secret\n' \
    > "${TEST_PROJECT_DIR}/.env"
  run "${MIGRATE_SH}" status
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing required variable: DB_PORT"* ]]
}

@test "env: missing DB_NAME exits with error" {
  printf 'DB_HOST=localhost\nDB_PORT=5432\nDB_USER=postgres\nDB_PASSWORD=secret\n' \
    > "${TEST_PROJECT_DIR}/.env"
  run "${MIGRATE_SH}" status
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing required variable: DB_NAME"* ]]
}

@test "env: missing DB_USER exits with error" {
  printf 'DB_HOST=localhost\nDB_PORT=5432\nDB_NAME=testdb\nDB_PASSWORD=secret\n' \
    > "${TEST_PROJECT_DIR}/.env"
  run "${MIGRATE_SH}" status
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing required variable: DB_USER"* ]]
}

@test "env: missing DB_PASSWORD exits with error" {
  printf 'DB_HOST=localhost\nDB_PORT=5432\nDB_NAME=testdb\nDB_USER=postgres\n' \
    > "${TEST_PROJECT_DIR}/.env"
  run "${MIGRATE_SH}" status
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing required variable: DB_PASSWORD"* ]]
}

# ---- psql availability ------------------------------------------------------

@test "env: psql not in PATH exits with error" {
  export PATH="/usr/bin:/bin"
  run "${MIGRATE_SH}" status
  [ "$status" -eq 1 ]
  [[ "$output" == *"psql is not installed"* ]]
}

# ---- Optional variables -----------------------------------------------------

@test "env: DB_SCHEMA defaults to public when not set" {
  run "${MIGRATE_SH}" status
  [ "$status" -eq 0 ]
}

@test "env: DB_SCHEMA can be overridden via .env" {
  printf 'DB_HOST=localhost\nDB_PORT=5432\nDB_NAME=testdb\nDB_USER=postgres\nDB_PASSWORD=secret\nDB_SCHEMA=myschema\n' \
    > "${TEST_PROJECT_DIR}/.env"
  run "${MIGRATE_SH}" status
  [ "$status" -eq 0 ]
}

@test "env: MIGRATIONS_DIR override is used" {
  local custom_dir
  custom_dir="$(mktemp -d)"
  printf "DB_HOST=localhost\nDB_PORT=5432\nDB_NAME=testdb\nDB_USER=postgres\nDB_PASSWORD=secret\nMIGRATIONS_DIR=${custom_dir}\n" \
    > "${TEST_PROJECT_DIR}/.env"
  run "${MIGRATE_SH}" up
  rm -rf "$custom_dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No pending migrations"* ]]
}

# ---- help does not require .env ---------------------------------------------

@test "env: help command works without .env" {
  rm "${TEST_PROJECT_DIR}/.env"
  run "${MIGRATE_SH}" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"PostgreSQL migration runner"* ]]
}

@test "env: invalid command without .env shows error" {
  rm "${TEST_PROJECT_DIR}/.env"
  run "${MIGRATE_SH}" badcommand
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid command"* ]]
}
