#!/usr/bin/env bash
# =============================================================================
# Command: create — scaffold a new migration file
# =============================================================================

cmd_create() {
  local name="${2:-}"

  if [[ -z "$name" ]]; then
    log_error "Usage: ./migrate.sh create <migration_name>"
    log_info "Example: ./migrate.sh create create_users_table"
    exit 1
  fi

  mkdir -p "$MIGRATIONS_DIR"

  # Timestamp prefix (YYYYMMDDHHMMSS) — collision-safe for parallel development
  local prefix
  prefix=$(date '+%Y%m%d%H%M%S')
  local filename="${prefix}_${name}.sql"
  local filepath="${MIGRATIONS_DIR}/${filename}"

  cat > "$filepath" <<'SQL'
-- UP


-- DOWN

SQL

  log_success "Created: ${MIGRATIONS_DIR}/${filename}"
}
