#!/usr/bin/env bash
# =============================================================================
# PostgreSQL Migration Runner — entry point
# =============================================================================
# Usage:
#   ./migrate.sh up                Apply all pending migrations
#   ./migrate.sh down              Rollback the last applied migration
#   ./migrate.sh status            Show migration status
#   ./migrate.sh create <name>     Create a new migration file
#   ./migrate.sh snapshot          Regenerate schemas/ snapshots
#
# Requires: psql, pg_dump, .env file with DB credentials
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PGMIGRATE_PROJECT_DIR:-$(pwd)}"

export SCRIPT_DIR PROJECT_DIR

# ---- Load library -----------------------------------------------------------

source "${SCRIPT_DIR}/lib/constants.sh"
source "${SCRIPT_DIR}/lib/helpers.sh"
source "${SCRIPT_DIR}/lib/db.sh"
source "${SCRIPT_DIR}/lib/snapshot.sh"

# ---- Load commands ----------------------------------------------------------

source "${SCRIPT_DIR}/commands/help.sh"
source "${SCRIPT_DIR}/commands/up.sh"
source "${SCRIPT_DIR}/commands/down.sh"
source "${SCRIPT_DIR}/commands/status.sh"
source "${SCRIPT_DIR}/commands/create.sh"
source "${SCRIPT_DIR}/commands/snapshot.sh"

# ---- Main -------------------------------------------------------------------

main() {
  local command="${1:-help}"

  case "$command" in
    help) cmd_help; return ;;
    up|down|status|create|snapshot) ;;
    *)
      log_error "invalid command \"${command}\""
      log_info  "hint: Try \"./migrate.sh help\" for more information."
      exit 1
      ;;
  esac

  load_env

  case "$command" in
    up)       cmd_up ;;
    down)     cmd_down ;;
    status)   cmd_status ;;
    create)   cmd_create "$@" ;;
    snapshot) cmd_snapshot ;;
  esac
}

main "$@"
