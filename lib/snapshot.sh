#!/usr/bin/env bash
# =============================================================================
# Snapshot — schema dump generation
# =============================================================================

# Dump the CREATE TABLE DDL for every public table (except _migrations)
# into individual files under schemas/
generate_schema_snapshot() {
  if ! command -v pg_dump &>/dev/null; then
    log_error "pg_dump is not installed or not in PATH."
    log_info  "Install PostgreSQL client tools and make sure pg_dump is available."
    exit 1
  fi

  mkdir -p "$SCHEMAS_DIR"

  local tables
  tables=$(run_sql -tAc "
    SELECT tablename FROM pg_tables
    WHERE schemaname = 'public' AND tablename != '_migrations'
    ORDER BY tablename;
  " 2>/dev/null || echo "")

  if [[ -z "$tables" ]]; then
    log_info "No tables found. Skipping snapshot."
    return
  fi

  while IFS= read -r table; do
    [[ -z "$table" ]] && continue

    local output_file="${SCHEMAS_DIR}/${table}.sql"

    {
      echo "-- Table: ${table}"
      echo "-- Auto-generated snapshot ($(date '+%Y-%m-%d %H:%M:%S'))"
      echo "-- DO NOT EXECUTE — this is a reference file only."
      echo ""
      PGPASSWORD="${DB_PASSWORD}" pg_dump \
        -h "${DB_HOST}" \
        -p "${DB_PORT}" \
        -U "${DB_USER}" \
        -d "${DB_NAME}" \
        --schema-only \
        --no-owner \
        --no-privileges \
        --no-comments \
        -t "${table}" 2>/dev/null \
        | sed '/^--/d; /^SET /d; /^SELECT /d; /^\\restrict /d; /^\\unrestrict /d; /^$/d'
    } > "$output_file"

    log_success "Snapshot: ${SCHEMAS_DIR}/${table}.sql"
  done <<< "$tables"
}
