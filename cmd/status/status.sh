#!/usr/bin/env bash
# =============================================================================
# Command: status — show which migrations are applied vs pending
# =============================================================================

cmd_status() {
  ensure_database
  check_connection
  ensure_migrations_table

  echo ""
  echo "Migration Status"
  echo "================"
  echo ""

  for file in "${MIGRATIONS_DIR}"/*.sql; do
    [[ -e "$file" ]] || { echo "  No migration files found."; break; }

    local filename
    filename=$(basename "$file")

    local applied
    applied=$(run_sql -tAc \
      "SELECT 1 FROM _migrations WHERE filename = '${filename}';" 2>/dev/null || echo "")

    if [[ "$applied" == "1" ]]; then
      echo -e "  ${GREEN}✓${NC}  ${filename}"
    else
      echo -e "  ${YELLOW}○${NC}  ${filename}  (pending)"
    fi
  done

  echo ""
}
