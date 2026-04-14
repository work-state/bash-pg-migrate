#!/usr/bin/env bash
# =============================================================================
# Database — connection helpers and schema bootstrapping
# =============================================================================

# ---- Query Runners ----------------------------------------------------------

# Run a SQL command against the target database
run_sql() {
  PGPASSWORD="${DB_PASSWORD}" psql \
    -h "${DB_HOST}" \
    -p "${DB_PORT}" \
    -d "${DB_NAME}" \
    -U "${DB_USER}" \
    --no-psqlrc \
    -v ON_ERROR_STOP=1 \
    "$@"
}

# ---- Connection Check -------------------------------------------------------

check_connection() {
  log_info "Connecting to ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}..."
  if run_sql -qc "SELECT 1;" &>/dev/null; then
    log_success "Connected to ${DB_HOST}:${DB_PORT}/${DB_NAME}"
  else
    log_error "Could not connect to ${DB_HOST}:${DB_PORT}/${DB_NAME} as '${DB_USER}'"
    exit 1
  fi
}

# ---- Schema Bootstrapping ---------------------------------------------------

# Verify the target database exists — exit with a clear error if it does not
ensure_database() {
  local db_exists
  db_exists=$(PGPASSWORD="${DB_PASSWORD}" psql \
    -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" \
    -d "postgres" --no-psqlrc -tAc \
    "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}';" 2>/dev/null || echo "")

  if [[ "$db_exists" != "1" ]]; then
    log_error "Database '${DB_NAME}' does not exist."
    log_info  "Create it first, then re-run this command."
    exit 1
  fi
}

# Create the _migrations tracking table if it does not exist
ensure_migrations_table() {
  run_sql -qc "
    CREATE TABLE IF NOT EXISTS _migrations (
      id          SERIAL PRIMARY KEY,
      filename    VARCHAR(255) NOT NULL UNIQUE,
      checksum    VARCHAR(64),
      applied_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  " 2>/dev/null
}
