#!/usr/bin/env bash
# =============================================================================
# Command: down — rollback the last applied migration, or the last N
# =============================================================================

cmd_down() {
  local count
  count=$(parse_step_count "down" "${@:2}") || exit 1
  count="${count:-1}"

  ensure_database
  check_connection
  ensure_migrations_table

  local files
  files=$(run_sql -tAc \
    "SELECT filename FROM _migrations ORDER BY filename DESC LIMIT ${count};" 2>/dev/null || echo "")

  if [[ -z "$files" ]]; then
    log_info "No migrations to rollback."
    return
  fi

  # Check every file before touching the database, so a missing file or
  # DOWN section can't stop the rollback halfway
  local last_file
  while IFS= read -r last_file; do
    [[ -z "$last_file" ]] && continue
    local file_path="${MIGRATIONS_DIR}/${last_file}"

    if [[ ! -f "$file_path" ]]; then
      log_error "Migration file not found: ${file_path}"
      exit 1
    fi

    if [[ -z "$(extract_down "$file_path")" ]]; then
      log_error "No -- DOWN section found in ${last_file}"
      exit 1
    fi
  done <<< "$files"

  local rolled_back=0

  while IFS= read -r last_file; do
    [[ -z "$last_file" ]] && continue

    local down_sql
    down_sql=$(extract_down "${MIGRATIONS_DIR}/${last_file}")

    log_info "Rolling back: ${last_file}"

    if run_sql <<SQL
BEGIN;

${down_sql}

DELETE FROM _migrations WHERE filename = '${last_file}';

COMMIT;
SQL
    then
      log_success "Rolled back: ${last_file}"
      rolled_back=$((rolled_back + 1))
    else
      log_error "Rollback failed: ${last_file}"
      # Rollbacks before this one are committed — keep schemas/ in sync
      [[ $rolled_back -gt 0 ]] && generate_schema_snapshot
      exit 1
    fi
  done <<< "$files"

  if [[ $rolled_back -lt $count ]]; then
    log_info "Only ${rolled_back} migration(s) were applied — all of them rolled back."
  fi
  [[ $count -gt 1 ]] && log_success "Rolled back ${rolled_back} migration(s)."

  generate_schema_snapshot
}
