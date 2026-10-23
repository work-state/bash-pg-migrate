#!/usr/bin/env bats
# =============================================================================
# Tests: snapshot command — per-table/view files and schema-level object files
# =============================================================================

load 'helpers/common'

setup()    { setup_test_env; }
teardown() { teardown_test_env; }

# ---- pg_dump not installed --------------------------------------------------

@test "snapshot: pg_dump not installed exits with error" {
  # Build a PATH that has mock psql but no pg_dump
  local tmp_bin
  tmp_bin="$(mktemp -d)"
  cp "${MOCKS_MIGRATE_DIR}/psql" "${tmp_bin}/psql"
  chmod +x "${tmp_bin}/psql"
  export PATH="${tmp_bin}:/usr/bin:/bin"

  run "${MIGRATE_SH}" snapshot
  rm -rf "$tmp_bin"
  [ "$status" -eq 1 ]
  [[ "$output" == *"pg_dump is not installed"* ]]
}

@test "snapshot: pg_restore not installed exits with error" {
  # Build a PATH that has mock psql and pg_dump but no pg_restore
  local tmp_bin
  tmp_bin="$(mktemp -d)"
  cp "${MOCKS_MIGRATE_DIR}/psql" "${MOCKS_MIGRATE_DIR}/pg_dump" "${tmp_bin}/"
  chmod +x "${tmp_bin}/psql" "${tmp_bin}/pg_dump"
  export PATH="${tmp_bin}:/usr/bin:/bin"

  run "${MIGRATE_SH}" snapshot
  rm -rf "$tmp_bin"
  [ "$status" -eq 1 ]
  [[ "$output" == *"pg_restore is not installed"* ]]
}

# ---- No tables --------------------------------------------------------------

@test "snapshot: no tables or views in schema reports it" {
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  [[ "$output" == *"No tables or views found"* ]]
}

@test "snapshot: no tables still writes schema-level object files" {
  export MOCK_OBJECTS="TYPE:order_status"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  [ -f "${TEST_PROJECT_DIR}/schemas/_types.sql" ]
}

# ---- Successful generation --------------------------------------------------

@test "snapshot: generates one file per table" {
  export MOCK_TABLES="users orders"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  [ -f "${TEST_PROJECT_DIR}/schemas/users.sql" ]
  [ -f "${TEST_PROJECT_DIR}/schemas/orders.sql" ]
}

@test "snapshot: snapshot file contains table name in header" {
  export MOCK_TABLES="users"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  grep -q "users" "${TEST_PROJECT_DIR}/schemas/users.sql"
}

@test "snapshot: snapshot file contains DO NOT EXECUTE warning" {
  export MOCK_TABLES="users"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  grep -q "DO NOT EXECUTE" "${TEST_PROJECT_DIR}/schemas/users.sql"
}

@test "snapshot: snapshot file contains auto-generated notice" {
  export MOCK_TABLES="users"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  grep -q "Auto-generated snapshot" "${TEST_PROJECT_DIR}/schemas/users.sql"
}

@test "snapshot: snapshot file contains CREATE TABLE statement" {
  export MOCK_TABLES="users"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  grep -q "CREATE TABLE" "${TEST_PROJECT_DIR}/schemas/users.sql"
}

@test "snapshot: snapshot file does not contain SET statements" {
  export MOCK_TABLES="users"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  ! grep -q "^SET " "${TEST_PROJECT_DIR}/schemas/users.sql"
}

@test "snapshot: snapshot file does not contain pg_dump comment lines" {
  export MOCK_TABLES="users"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  # pg_dump emits "-- Name: ...; Type: ..." style comments — sed filter must strip them
  ! grep -qE "^-- Name:.*Type:" "${TEST_PROJECT_DIR}/schemas/users.sql"
}

@test "snapshot: snapshot file does not contain SET statements from pg_dump" {
  export MOCK_TABLES="users"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  ! grep -qE "^SET " "${TEST_PROJECT_DIR}/schemas/users.sql"
}

@test "snapshot: prints success message per table" {
  export MOCK_TABLES="users orders"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  [[ "$output" == *"Snapshot:"*"users.sql"* ]]
  [[ "$output" == *"Snapshot:"*"orders.sql"* ]]
}

@test "snapshot: creates schemas directory if it does not exist" {
  rmdir "${TEST_PROJECT_DIR}/schemas"
  export MOCK_TABLES="users"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  [ -d "${TEST_PROJECT_DIR}/schemas" ]
}

# ---- Views ------------------------------------------------------------------

@test "snapshot: generates one file per view" {
  export MOCK_VIEWS="open_orders"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  grep -q "^-- View: public.open_orders" "${TEST_PROJECT_DIR}/schemas/open_orders.sql"
}

@test "snapshot: generates one file per materialized view" {
  export MOCK_MATVIEWS="revenue_by_status"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  grep -q "^-- Materialized view: public.revenue_by_status" "${TEST_PROJECT_DIR}/schemas/revenue_by_status.sql"
}

# ---- Extended statistics ----------------------------------------------------

@test "snapshot: appends extended statistics to the table file" {
  export MOCK_TABLES="users orders"
  export MOCK_STATISTICS="users:users_stats"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  grep -q "CREATE STATISTICS public.users_stats" "${TEST_PROJECT_DIR}/schemas/users.sql"
  ! grep -q "CREATE STATISTICS" "${TEST_PROJECT_DIR}/schemas/orders.sql"
}

# ---- Extensions -------------------------------------------------------------

@test "snapshot: writes installed extensions to _extensions.sql" {
  export MOCK_EXTENSIONS="citext btree_gist"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  grep -q "CREATE EXTENSION IF NOT EXISTS citext" "${TEST_PROJECT_DIR}/schemas/_extensions.sql"
  grep -q "CREATE EXTENSION IF NOT EXISTS btree_gist" "${TEST_PROJECT_DIR}/schemas/_extensions.sql"
}

@test "snapshot: no extensions writes no _extensions.sql" {
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  [ ! -f "${TEST_PROJECT_DIR}/schemas/_extensions.sql" ]
}

# ---- Types ------------------------------------------------------------------

@test "snapshot: writes enum and domain declarations to _types.sql" {
  export MOCK_OBJECTS="TYPE:order_status DOMAIN:positive_money"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  grep -q "CREATE TYPE public.order_status" "${TEST_PROJECT_DIR}/schemas/_types.sql"
  grep -q "CREATE DOMAIN public.positive_money" "${TEST_PROJECT_DIR}/schemas/_types.sql"
}

@test "snapshot: _types.sql includes comments on types" {
  export MOCK_OBJECTS="TYPE:order_status"
  export MOCK_COMMENTS="TYPE:order_status"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  grep -q "COMMENT ON TYPE public.order_status" "${TEST_PROJECT_DIR}/schemas/_types.sql"
}

@test "snapshot: _types.sql has header and no pg_dump noise" {
  export MOCK_OBJECTS="TYPE:order_status"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  grep -q "DO NOT EXECUTE" "${TEST_PROJECT_DIR}/schemas/_types.sql"
  ! grep -qE "^SET |^SELECT pg_catalog|^-- Name:|^-- PostgreSQL" "${TEST_PROJECT_DIR}/schemas/_types.sql"
}

@test "snapshot: _types.sql does not include tables or owned sequences" {
  export MOCK_OBJECTS="TYPE:order_status"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  ! grep -qE "TABLE|SEQUENCE|SCHEMA" "${TEST_PROJECT_DIR}/schemas/_types.sql"
}

# ---- Functions --------------------------------------------------------------

@test "snapshot: writes functions, procedures and aggregates to _functions.sql" {
  export MOCK_OBJECTS="FUNCTION:set_updated_at() PROCEDURE:archive_docs() AGGREGATE:sum2(integer)"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  grep -q "CREATE FUNCTION public.set_updated_at()" "${TEST_PROJECT_DIR}/schemas/_functions.sql"
  grep -q "CREATE PROCEDURE public.archive_docs()" "${TEST_PROJECT_DIR}/schemas/_functions.sql"
  grep -q "CREATE AGGREGATE public.sum2(integer)" "${TEST_PROJECT_DIR}/schemas/_functions.sql"
}

@test "snapshot: keeps SELECT and comment lines inside function bodies" {
  export MOCK_OBJECTS="FUNCTION:one()"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  grep -qx "SELECT 1" "${TEST_PROJECT_DIR}/schemas/_functions.sql"
  grep -qx -- "-- keep this body comment" "${TEST_PROJECT_DIR}/schemas/_functions.sql"
}

# ---- Sequences --------------------------------------------------------------

@test "snapshot: writes only standalone sequences to _sequences.sql" {
  export MOCK_OBJECTS="SEQUENCE:invoice_number_seq"
  export MOCK_STANDALONE_SEQUENCES="invoice_number_seq"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  grep -q "CREATE SEQUENCE public.invoice_number_seq" "${TEST_PROJECT_DIR}/schemas/_sequences.sql"
  # users_id_seq is owned by users.id — it belongs in users.sql
  ! grep -q "users_id_seq" "${TEST_PROJECT_DIR}/schemas/_sequences.sql"
}

@test "snapshot: no standalone sequences writes no _sequences.sql" {
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  [ ! -f "${TEST_PROJECT_DIR}/schemas/_sequences.sql" ]
}

# ---- Collations and text search ---------------------------------------------

@test "snapshot: writes collations to _collations.sql" {
  export MOCK_OBJECTS="COLLATION:ci"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  grep -q "CREATE COLLATION public.ci" "${TEST_PROJECT_DIR}/schemas/_collations.sql"
}

@test "snapshot: writes text search objects to _text_search.sql" {
  export MOCK_OBJECTS="TEXT_SEARCH_CONFIGURATION:en_simple TEXT_SEARCH_DICTIONARY:en_dict"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  grep -q "CREATE TEXT SEARCH CONFIGURATION public.en_simple" "${TEST_PROJECT_DIR}/schemas/_text_search.sql"
  grep -q "CREATE TEXT SEARCH DICTIONARY public.en_dict" "${TEST_PROJECT_DIR}/schemas/_text_search.sql"
}

# ---- Stale object files -----------------------------------------------------

@test "snapshot: removes object files whose objects no longer exist" {
  local file
  for file in _extensions _types _sequences _functions _collations _text_search; do
    echo "-- stale" > "${TEST_PROJECT_DIR}/schemas/${file}.sql"
  done
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  for file in _extensions _types _sequences _functions _collations _text_search; do
    [ ! -f "${TEST_PROJECT_DIR}/schemas/${file}.sql" ]
  done
}

# ---- Foreign tables ---------------------------------------------------------

@test "snapshot: warns about foreign tables it does not snapshot" {
  export MOCK_FOREIGN_TABLES="remote_docs remote_users"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  [[ "$output" == *"Foreign tables are not snapshotted yet: remote_docs, remote_users"* ]]
}

@test "snapshot: no foreign tables prints no warning" {
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  [[ "$output" != *"Foreign tables"* ]]
}

# ---- pg_dump failure --------------------------------------------------------

@test "snapshot: pg_dump failure warns that object files were not updated" {
  export MOCK_PG_DUMP_FAIL=1
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  [[ "$output" == *"Could not dump schema objects"* ]]
  [[ "$output" == *"Connection refused"* ]]
}

# ---- Stale table and view files ---------------------------------------------

# Write a file that looks like a previous pgmigrate snapshot
# Usage: write_old_snapshot <name> [kind]
write_old_snapshot() {
  cat > "${TEST_PROJECT_DIR}/schemas/${1}.sql" <<SQL
-- ${2:-Table}: public.${1}
-- Database: testdb
-- Auto-generated snapshot (2026-01-01 00:00:00)
-- DO NOT EXECUTE — this is a reference file only.
SQL
}

@test "snapshot: removes the file of a dropped table" {
  write_old_snapshot "old_table"
  export MOCK_TABLES="users"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  [ ! -f "${TEST_PROJECT_DIR}/schemas/old_table.sql" ]
  [ -f "${TEST_PROJECT_DIR}/schemas/users.sql" ]
  [[ "$output" == *"Removed snapshot:"*"old_table.sql"* ]]
}

@test "snapshot: removes the files of dropped views and materialized views" {
  write_old_snapshot "old_view" "View"
  write_old_snapshot "old_matview" "Materialized view"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  [ ! -f "${TEST_PROJECT_DIR}/schemas/old_view.sql" ]
  [ ! -f "${TEST_PROJECT_DIR}/schemas/old_matview.sql" ]
}

@test "snapshot: removes table files when the last table is dropped" {
  write_old_snapshot "users"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  [ ! -f "${TEST_PROJECT_DIR}/schemas/users.sql" ]
}

@test "snapshot: rewrites the file of a table that still exists" {
  write_old_snapshot "users"
  echo "    legacy_column text," >> "${TEST_PROJECT_DIR}/schemas/users.sql"
  export MOCK_TABLES="users"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  grep -q "CREATE TABLE" "${TEST_PROJECT_DIR}/schemas/users.sql"
  ! grep -q "legacy_column" "${TEST_PROJECT_DIR}/schemas/users.sql"
}

@test "snapshot: keeps files in schemas/ that pgmigrate did not generate" {
  echo "CREATE TABLE notes (id int);" > "${TEST_PROJECT_DIR}/schemas/notes.sql"
  echo "-- Table: public.handwritten" > "${TEST_PROJECT_DIR}/schemas/handwritten.sql"
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  [ -f "${TEST_PROJECT_DIR}/schemas/notes.sql" ]
  [ -f "${TEST_PROJECT_DIR}/schemas/handwritten.sql" ]
}

@test "snapshot: failed table listing warns and removes nothing" {
  write_old_snapshot "users"
  export MOCK_RELATIONS_FAIL=1
  run "${MIGRATE_SH}" snapshot
  [ "$status" -eq 0 ]
  [[ "$output" == *"Could not list tables and views"* ]]
  [ -f "${TEST_PROJECT_DIR}/schemas/users.sql" ]
}
