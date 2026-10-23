#!/usr/bin/env bash
# =============================================================================
# Snapshot — schema dump split into one file per table/view plus one file per
# kind of schema-level object (types, functions, sequences, ...)
# =============================================================================

# Remove the noise pg_dump/pg_restore add around the DDL. Only pg_dump's own
# lines are matched, so SQL inside function and view bodies is left intact.
clean_dump_output() {
  sed -E \
    -e '/^--$/d' \
    -e '/^-- (Name|TOC entry|Dependencies|PostgreSQL database dump|Dumped (from|by)|Started on|Completed on)/d' \
    -e '/^SET /d' \
    -e '/^SELECT pg_catalog\.set_config\(/d' \
    -e '/^\\(connect|restrict|unrestrict) /d' \
    -e '/^$/d'
}

# Escape a string for use inside an ERE pattern
escape_regex() {
  printf '%s' "$1" | sed 's/[][\.*^$+?(){}|/]/\\&/g'
}

# Usage: write_snapshot_header <title> <includes> [excludes]
write_snapshot_header() {
  echo "-- ${1}"
  echo "-- Database: ${DB_NAME}"
  echo "-- Auto-generated snapshot ($(date '+%Y-%m-%d %H:%M:%S'))"
  echo "-- DO NOT EXECUTE — this is a reference file only."
  echo "--"
  echo "-- Includes: ${2}"
  [[ -n "${3:-}" ]] && echo "-- Excludes: ${3}"
  echo "-- The migrations/ directory is the source of truth for schema changes."
  echo ""
}

# Write the selected entries of a schema-only archive into one file. Removes
# the file when nothing matches, so dropped objects don't leave stale files.
# Usage: write_object_snapshot <archive> <toc> <file> <title> <includes> <kinds_regex> [names_regex]
write_object_snapshot() {
  local archive="$1" toc="$2" output_file="$3" title="$4" includes="$5" kinds="$6"
  local names="${7:-.+}"
  local schema list
  schema=$(escape_regex "$DB_SCHEMA")
  list="${archive}.list"

  # TOC lines: "<id>; <oid> <oid> <KIND> <schema> <name> <owner>"
  #            "<id>; 0 0 COMMENT <schema> <KIND> <name> <owner>"
  grep -E \
    -e "^[0-9]+; [0-9]+ [0-9]+ (${kinds}) ${schema} (${names}) [^ ]+$" \
    -e "^[0-9]+; [0-9]+ [0-9]+ COMMENT ${schema} (${kinds}) (${names}) [^ ]+$" \
    "$toc" > "$list" || true

  if [[ ! -s "$list" ]]; then
    rm -f "$output_file"
    return
  fi

  {
    write_snapshot_header "$title" "$includes"
    pg_restore --no-owner --no-privileges -L "$list" -f - "$archive" | clean_dump_output
  } > "$output_file"

  log_success "Snapshot: ${output_file}"
}

# Write _extensions.sql: every extension installed in the database (except
# the built-in plpgsql), whichever schema it lives in, since columns in
# DB_SCHEMA can use types from an extension installed elsewhere
write_extensions_snapshot() {
  local output_file="${SCHEMAS_DIR}/_extensions.sql"
  local extensions
  extensions=$(run_sql -tAc "
    SELECT format('CREATE EXTENSION IF NOT EXISTS %I WITH SCHEMA %I;', e.extname, n.nspname)
    FROM pg_extension e JOIN pg_namespace n ON n.oid = e.extnamespace
    WHERE e.extname <> 'plpgsql'
    ORDER BY e.extname;
  " 2>/dev/null || echo "")

  if [[ -z "$extensions" ]]; then
    rm -f "$output_file"
    return
  fi

  {
    write_snapshot_header "Extensions" "every extension installed in the database (except plpgsql)."
    echo "$extensions"
  } > "$output_file"

  log_success "Snapshot: ${output_file}"
}

# Write the schema-level object files (_types, _sequences, _functions,
# _collations, _text_search) from one schema-only archive of DB_SCHEMA
write_object_snapshots() {
  local tmp_dir archive toc err
  tmp_dir="$(mktemp -d)"
  archive="${tmp_dir}/schema.dump"
  toc="${tmp_dir}/schema.toc"

  if ! err=$(PGPASSWORD="${DB_PASSWORD}" pg_dump \
      -h "${DB_HOST}" \
      -p "${DB_PORT}" \
      -U "${DB_USER}" \
      -d "${DB_NAME}" \
      --schema-only \
      --format=custom \
      --no-owner \
      --no-privileges \
      --schema="${DB_SCHEMA}" \
      -f "$archive" 2>&1); then
    log_warn "Could not dump schema objects — types, functions, sequences, collations and text search files not updated."
    [[ -n "$err" ]] && log_warn "${err}"
    rm -rf "$tmp_dir"
    return
  fi

  pg_restore -l "$archive" > "$toc"

  # Sequences owned by a column (serial, identity) are already in their table's file
  local standalone_sequences sequence names=""
  standalone_sequences=$(run_sql -tAc "
    SELECT c.relname FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = '${DB_SCHEMA}' AND c.relkind = 'S'
      AND NOT EXISTS (
        SELECT 1 FROM pg_depend d
        WHERE d.classid = 'pg_class'::regclass AND d.objid = c.oid
          AND d.refclassid = 'pg_class'::regclass AND d.deptype IN ('a', 'i')
      )
    ORDER BY c.relname;
  " 2>/dev/null || echo "")

  while IFS= read -r sequence; do
    [[ -z "$sequence" ]] && continue
    names+="${names:+|}$(escape_regex "$sequence")"
  done <<< "$standalone_sequences"

  write_object_snapshot "$archive" "$toc" "${SCHEMAS_DIR}/_types.sql" \
    "Types in schema: ${DB_SCHEMA}" "enums, composite types, range types and domains." \
    "TYPE|DOMAIN"

  if [[ -n "$names" ]]; then
    write_object_snapshot "$archive" "$toc" "${SCHEMAS_DIR}/_sequences.sql" \
      "Sequences in schema: ${DB_SCHEMA}" "standalone sequences (sequences owned by a column are in that table's file)." \
      "SEQUENCE" "$names"
  else
    rm -f "${SCHEMAS_DIR}/_sequences.sql"
  fi

  write_object_snapshot "$archive" "$toc" "${SCHEMAS_DIR}/_functions.sql" \
    "Functions in schema: ${DB_SCHEMA}" "functions, procedures and aggregates." \
    "FUNCTION|PROCEDURE|AGGREGATE"

  write_object_snapshot "$archive" "$toc" "${SCHEMAS_DIR}/_collations.sql" \
    "Collations in schema: ${DB_SCHEMA}" "custom collations." \
    "COLLATION"

  write_object_snapshot "$archive" "$toc" "${SCHEMAS_DIR}/_text_search.sql" \
    "Text search objects in schema: ${DB_SCHEMA}" "text search configurations, dictionaries, parsers and templates." \
    "TEXT SEARCH (CONFIGURATION|DICTIONARY|PARSER|TEMPLATE)"

  rm -rf "$tmp_dir"
}

# Delete table/view files whose table or view no longer exists (dropped or
# renamed). Only files carrying pgmigrate's own header are touched, so other
# files in SCHEMAS_DIR are left alone.
# Usage: remove_stale_relation_snapshots <newline-separated relation names>
remove_stale_relation_snapshots() {
  local current="$1" file name
  for file in "${SCHEMAS_DIR}"/*.sql; do
    [[ -f "$file" ]] || continue
    name="$(basename "$file" .sql)"
    [[ "$name" == _* ]] && continue
    grep -qxF -- "$name" <<< "$current" && continue
    head -n 1 "$file" | grep -qE "^-- (Table|View|Materialized view): " || continue
    sed -n 4p "$file" | grep -qF -- "-- DO NOT EXECUTE" || continue

    rm -f "$file"
    log_info "Removed snapshot: ${file}"
  done
}

# Write one file per table, partitioned table, view and materialized view.
# Each table file captures its columns, owned sequences, indexes, constraints,
# triggers, rules, policies, extended statistics, comments and outgoing foreign
# keys. Incoming FK constraints (defined on other tables) are not included.
write_relation_snapshots() {
  local relations
  # A failed query must not look like "no tables" — that would delete every file
  if ! relations=$(run_sql -tAc "
    SELECT c.relname || '|' || c.relkind::text FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = '${DB_SCHEMA}' AND c.relkind IN ('r', 'p', 'v', 'm')
      AND c.relname <> '_migrations'
      AND NOT EXISTS (
        SELECT 1 FROM pg_depend d
        WHERE d.classid = 'pg_class'::regclass AND d.objid = c.oid AND d.deptype = 'e'
      )
    ORDER BY c.relname;
  " 2>/dev/null); then
    log_warn "Could not list tables and views — table and view files not updated."
    return
  fi

  remove_stale_relation_snapshots "$(cut -d'|' -f1 <<< "$relations")"

  if [[ -z "$relations" ]]; then
    log_info "No tables or views found in schema '${DB_SCHEMA}'."
    return
  fi

  local relation kind
  while IFS='|' read -r relation kind; do
    [[ -z "$relation" ]] && continue

    local output_file="${SCHEMAS_DIR}/${relation}.sql"
    local title includes excludes=""

    case "$kind" in
      v) title="View: ${DB_SCHEMA}.${relation}"
         includes="view definition and comments." ;;
      m) title="Materialized view: ${DB_SCHEMA}.${relation}"
         includes="view definition, indexes, extended statistics and comments." ;;
      *) title="Table: ${DB_SCHEMA}.${relation}"
         includes="columns, sequences, indexes, constraints, triggers, rules, policies, extended statistics, comments and outgoing FK references."
         excludes="FK constraints from other tables pointing to this one." ;;
    esac

    local ddl statistics statement
    ddl=$(PGPASSWORD="${DB_PASSWORD}" pg_dump \
      -h "${DB_HOST}" \
      -p "${DB_PORT}" \
      -U "${DB_USER}" \
      -d "${DB_NAME}" \
      --schema-only \
      --no-owner \
      --no-privileges \
      --schema="${DB_SCHEMA}" \
      -t "${DB_SCHEMA}.${relation}" \
      2>/dev/null | clean_dump_output || true)

    # pg_dump -t leaves out extended statistics; append the ones it didn't print
    if [[ "$kind" != "v" ]]; then
      statistics=$(run_sql -tAc "
        SELECT pg_get_statisticsobjdef(s.oid) || ';' FROM pg_statistic_ext s
        WHERE s.stxrelid = format('%I.%I', '${DB_SCHEMA}', '${relation}')::regclass
        ORDER BY s.stxname;
      " 2>/dev/null || echo "")

      while IFS= read -r statement; do
        [[ -z "$statement" ]] && continue
        grep -qxF -- "$statement" <<< "$ddl" || ddl+=$'\n'"${statement}"
      done <<< "$statistics"
    fi

    {
      write_snapshot_header "$title" "$includes" "$excludes"
      echo "$ddl"
    } > "$output_file"

    log_success "Snapshot: ${output_file}"
  done <<< "$relations"
}

# Foreign tables aren't snapshotted yet — say so instead of skipping them silently
warn_foreign_tables() {
  local foreign_tables
  foreign_tables=$(run_sql -tAc "
    SELECT string_agg(c.relname, ', ' ORDER BY c.relname) FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = '${DB_SCHEMA}' AND c.relkind = 'f';
  " 2>/dev/null || echo "")

  if [[ -n "$foreign_tables" ]]; then
    log_warn "Foreign tables are not snapshotted yet: ${foreign_tables}"
  fi
}

generate_schema_snapshot() {
  local tool
  for tool in pg_dump pg_restore; do
    if ! command -v "$tool" &>/dev/null; then
      log_error "${tool} is not installed or not in PATH."
      log_info  "Install PostgreSQL client tools and make sure ${tool} is available."
      exit 1
    fi
  done

  mkdir -p "$SCHEMAS_DIR"

  write_extensions_snapshot
  write_object_snapshots
  write_relation_snapshots
  warn_foreign_tables
}
