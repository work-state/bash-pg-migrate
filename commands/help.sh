#!/usr/bin/env bash
# =============================================================================
# Command: help — show usage information
# =============================================================================

cmd_help() {
  echo "PostgreSQL migration runner"
  echo ""
  echo "Usage:"
  echo "  ./migrate.sh [OPTION]..."
  echo ""
  echo "General options:"
  echo "  ./migrate.sh up               Apply all pending migrations"
  echo "  ./migrate.sh down             Rollback last migration"
  echo "  ./migrate.sh status           Show migration status"
  echo "  ./migrate.sh create <name>    Create a new migration file"
  echo "  ./migrate.sh snapshot         Regenerate schema snapshots"
  echo ""
  echo "Install options (global install only):"
  echo "  pgmigrate uninstall           Remove pgmigrate from the system"
}
