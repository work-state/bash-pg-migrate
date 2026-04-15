#!/usr/bin/env bash
# =============================================================================
# Snapshot — per-table schema dump
# =============================================================================

# Dump the DDL for every table in DB_SCHEMA into individual files under schemas/.
# Each file captures the table's own columns, indexes, sequences, and outgoing
# foreign key constraints. Incoming FK constraints (defined on other tables) are
# not included — see header comment written into each file.
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
    WHERE schemaname = '${DB_SCHEMA}' AND tablename != '_migrations'
    ORDER BY tablename;
  " 2>/dev/null || echo "")

  if [[ -z "$tables" ]]; then
    log_info "No tables found in schema '${DB_SCHEMA}'. Skipping snapshot."
    return
  fi

  while IFS= read -r table; do
    [[ -z "$table" ]] && continue

    local output_file="${SCHEMAS_DIR}/${table}.sql"

    {
      echo "-- Table: ${DB_SCHEMA}.${table}"
      echo "-- Database: ${DB_NAME}"
      echo "-- Auto-generated snapshot ($(date '+%Y-%m-%d %H:%M:%S'))"
      echo "-- DO NOT EXECUTE — this is a reference file only."
      echo "--"
      echo "-- Includes: columns, sequences, indexes, constraints, and outgoing FK references."
      echo "-- Excludes: FK constraints from other tables pointing to this one."
      echo "-- The migrations/ directory is the source of truth for schema changes."
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
        --schema="${DB_SCHEMA}" \
        -t "${DB_SCHEMA}.${table}" \
        2>/dev/null \
        | sed '/^--/d; /^SET /d; /^SELECT /d; /^\\connect /d; /^\\restrict /d; /^\\unrestrict /d; /^$/d'
    } > "$output_file"

    log_success "Snapshot: ${output_file}"
  done <<< "$tables"
}
