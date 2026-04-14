#!/usr/bin/env bash
# =============================================================================
# Command: down — rollback the last applied migration
# =============================================================================

cmd_down() {
  ensure_database
  check_connection
  ensure_migrations_table

  local last_file
  last_file=$(run_sql -tAc \
    "SELECT filename FROM _migrations ORDER BY filename DESC LIMIT 1;" 2>/dev/null || echo "")

  if [[ -z "$last_file" ]]; then
    log_info "No migrations to rollback."
    return
  fi

  local file_path="${MIGRATIONS_DIR}/${last_file}"

  if [[ ! -f "$file_path" ]]; then
    log_error "Migration file not found: ${file_path}"
    exit 1
  fi

  local down_sql
  down_sql=$(extract_down "$file_path")

  if [[ -z "$down_sql" ]]; then
    log_error "No -- DOWN section found in ${last_file}"
    exit 1
  fi

  log_info "Rolling back: ${last_file}"

  run_sql <<SQL
BEGIN;

${down_sql}

DELETE FROM _migrations WHERE filename = '${last_file}';

COMMIT;
SQL

  if [[ $? -eq 0 ]]; then
    log_success "Rolled back: ${last_file}"
    generate_schema_snapshot
  else
    log_error "Rollback failed: ${last_file}"
    exit 1
  fi
}
