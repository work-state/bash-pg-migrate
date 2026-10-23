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

  local files=("${MIGRATIONS_DIR}"/*.sql)

  if [[ ! -e "${files[0]}" ]]; then
    echo "  No migration files found."
    echo ""
    return
  fi

  # Pad numbers to the widest one so file names stay aligned
  local width=${#files[@]}
  width=${#width}
  local index=0

  for file in "${files[@]}"; do
    index=$((index + 1))

    local filename
    filename=$(basename "$file")

    local applied
    applied=$(run_sql -tAc \
      "SELECT 1 FROM _migrations WHERE filename = '${filename}';" 2>/dev/null || echo "")

    if [[ "$applied" == "1" ]]; then
      printf "  %${width}d. %b  %s\n" "$index" "${GREEN}✓${NC}" "$filename"
    else
      printf "  %${width}d. %b  %s  (pending)\n" "$index" "${YELLOW}○${NC}" "$filename"
    fi
  done

  echo ""
}
