#!/usr/bin/env bash
# =============================================================================
# Command: up — apply all pending migrations, or only the next N
# =============================================================================

cmd_up() {
  local limit
  limit=$(parse_step_count "up" "${@:2}") || exit 1

  ensure_database
  check_connection
  ensure_migrations_table

  if [[ ! -d "$MIGRATIONS_DIR" ]]; then
    log_warn "No migrations directory found at ${MIGRATIONS_DIR}"
    exit 0
  fi

  local pending=0

  while IFS= read -r file; do
    [[ -e "$file" ]] || continue

    local filename
    filename=$(basename "$file")

    # Skip already-applied migrations (but verify their checksum hasn't changed)
    local applied
    applied=$(run_sql -tAc \
      "SELECT 1 FROM _migrations WHERE filename = '${filename}';" 2>/dev/null || echo "")

    if [[ "$applied" == "1" ]]; then
      local stored_checksum
      stored_checksum=$(run_sql -tAc \
        "SELECT checksum FROM _migrations WHERE filename = '${filename}';" 2>/dev/null || echo "")

      if [[ -n "$stored_checksum" ]]; then
        local current_checksum
        current_checksum=$(compute_checksum "$file")
        if [[ "$current_checksum" != "$stored_checksum" ]]; then
          log_error "Checksum mismatch: ${filename} was modified after being applied."
          log_error "  stored:  ${stored_checksum}"
          log_error "  current: ${current_checksum}"
          exit 1
        fi
      else
        log_warn "No checksum stored for: ${filename}"
      fi
      continue
    fi

    # Keep scanning past the limit so applied migrations still get their checksum verified
    if [[ -n "$limit" && $pending -ge $limit ]]; then
      continue
    fi

    local up_sql
    up_sql=$(extract_up "$file")

    if [[ -z "$up_sql" ]]; then
      log_error "No -- UP section found in ${filename}"
      [[ $pending -gt 0 ]] && generate_schema_snapshot
      exit 1
    fi

    local checksum
    checksum=$(compute_checksum "$file")

    log_info "Applying: ${filename}"

    if run_sql <<SQL
BEGIN;

${up_sql}

INSERT INTO _migrations (filename, checksum) VALUES ('${filename}', '${checksum}');

COMMIT;
SQL
    then
      log_success "Applied: ${filename}"
      pending=$((pending + 1))
    else
      log_error "Failed: ${filename}"
      # Migrations applied before this one are committed — keep schemas/ in sync
      [[ $pending -gt 0 ]] && generate_schema_snapshot
      exit 1
    fi
  done < <(printf '%s\n' "${MIGRATIONS_DIR}"/*.sql | sort)

  if [[ $pending -eq 0 ]]; then
    log_info "No pending migrations."
  else
    log_success "Applied ${pending} migration(s)."
    generate_schema_snapshot
  fi
}
