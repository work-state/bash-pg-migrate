#!/usr/bin/env bats
# =============================================================================
# Tests: .env.* auto-discovery and .pgmigrate variable name mapping
# =============================================================================

load 'helpers/common'

setup()    { setup_test_env; }
teardown() { teardown_test_env; }

# ---- .env.* auto-discovery --------------------------------------------------

@test "mapping: .env.development with standard variable names works without .pgmigrate" {
  rm "${TEST_PROJECT_DIR}/.env"
  cat > "${TEST_PROJECT_DIR}/.env.development" <<EOF
DB_HOST=localhost
DB_PORT=5432
DB_NAME=testdb
DB_USER=postgres
DB_PASSWORD=secret
EOF
  run "${MIGRATE_SH}" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Using env file: .env.development"* ]]
}

# ---- Custom variable names — no .pgmigrate ----------------------------------

@test "mapping: .env.development with custom variable names and no .pgmigrate fails" {
  rm "${TEST_PROJECT_DIR}/.env"
  cat > "${TEST_PROJECT_DIR}/.env.development" <<EOF
PGHOST=localhost
PGPORT=5432
PGDATABASE=testdb
PGUSER=postgres
PGPASSWORD=secret
EOF
  run "${MIGRATE_SH}" status
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing required variable: DB_HOST"* ]]
  [[ "$output" == *".pgmigrate"* ]]
}

@test "mapping: .env with custom variable names and no .pgmigrate fails" {
  cat > "${TEST_PROJECT_DIR}/.env" <<EOF
PGHOST=localhost
PGPORT=5432
PGDATABASE=testdb
PGUSER=postgres
PGPASSWORD=secret
EOF
  run "${MIGRATE_SH}" status
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing required variable: DB_HOST"* ]]
  [[ "$output" == *".pgmigrate"* ]]
}

# ---- .pgmigrate with wrong mappings -----------------------------------------

@test "mapping: .env.development with custom variable names and wrong .pgmigrate mappings fails" {
  rm "${TEST_PROJECT_DIR}/.env"
  cat > "${TEST_PROJECT_DIR}/.env.development" <<EOF
PGHOST=localhost
PGPORT=5432
PGDATABASE=testdb
PGUSER=postgres
PGPASSWORD=secret
EOF
  cat > "${TEST_PROJECT_DIR}/.pgmigrate" <<EOF
DB_HOST=WRONG_HOST_VAR
DB_PORT=WRONG_PORT_VAR
DB_NAME=WRONG_NAME_VAR
DB_USER=WRONG_USER_VAR
DB_PASSWORD=WRONG_PASS_VAR
EOF
  run "${MIGRATE_SH}" status
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing required variable: DB_HOST"* ]]
  [[ "$output" == *".pgmigrate"* ]]
  [[ "$output" == *"may not be mapped correctly"* ]]
}

@test "mapping: .env with custom variable names and wrong .pgmigrate mappings fails" {
  cat > "${TEST_PROJECT_DIR}/.env" <<EOF
PGHOST=localhost
PGPORT=5432
PGDATABASE=testdb
PGUSER=postgres
PGPASSWORD=secret
EOF
  cat > "${TEST_PROJECT_DIR}/.pgmigrate" <<EOF
DB_HOST=WRONG_HOST_VAR
DB_PORT=WRONG_PORT_VAR
DB_NAME=WRONG_NAME_VAR
DB_USER=WRONG_USER_VAR
DB_PASSWORD=WRONG_PASS_VAR
EOF
  run "${MIGRATE_SH}" status
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing required variable: DB_HOST"* ]]
  [[ "$output" == *".pgmigrate"* ]]
  [[ "$output" == *"may not be mapped correctly"* ]]
}

# ---- .pgmigrate with correct mappings ---------------------------------------

@test "mapping: .env.development with custom variable names and correct .pgmigrate succeeds" {
  rm "${TEST_PROJECT_DIR}/.env"
  cat > "${TEST_PROJECT_DIR}/.env.development" <<EOF
PGHOST=localhost
PGPORT=5432
PGDATABASE=testdb
PGUSER=postgres
PGPASSWORD=secret
EOF
  cat > "${TEST_PROJECT_DIR}/.pgmigrate" <<EOF
DB_HOST=PGHOST
DB_PORT=PGPORT
DB_NAME=PGDATABASE
DB_USER=PGUSER
DB_PASSWORD=PGPASSWORD
EOF
  run "${MIGRATE_SH}" status
  [ "$status" -eq 0 ]
}

@test "mapping: .env with custom variable names and correct .pgmigrate succeeds" {
  cat > "${TEST_PROJECT_DIR}/.env" <<EOF
PGHOST=localhost
PGPORT=5432
PGDATABASE=testdb
PGUSER=postgres
PGPASSWORD=secret
EOF
  cat > "${TEST_PROJECT_DIR}/.pgmigrate" <<EOF
DB_HOST=PGHOST
DB_PORT=PGPORT
DB_NAME=PGDATABASE
DB_USER=PGUSER
DB_PASSWORD=PGPASSWORD
EOF
  run "${MIGRATE_SH}" status
  [ "$status" -eq 0 ]
}

@test "mapping: last line of .pgmigrate is mapped even without trailing newline" {
  cat > "${TEST_PROJECT_DIR}/.env" <<EOF
PGHOST=localhost
PGPORT=5432
PGDATABASE=testdb
PGUSER=postgres
PGPASSWORD=secret
EOF
  # Intentionally no trailing newline — DB_USER is the last line
  printf 'DB_HOST=PGHOST\nDB_PORT=PGPORT\nDB_NAME=PGDATABASE\nDB_PASSWORD=PGPASSWORD\nDB_USER=PGUSER' \
    > "${TEST_PROJECT_DIR}/.pgmigrate"
  run "${MIGRATE_SH}" status
  [ "$status" -eq 0 ]
}
