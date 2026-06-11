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
  echo "Configuration:"
  echo "  pgmigrate reads credentials from a .env file in the project root."
  echo "  Supported filenames: .env, .env.local, .env.development, .env.*"
  echo ""
  echo "  Required variables (default names):"
  echo "    DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD"
  echo ""
  echo "  If your .env uses different variable names (e.g. PGHOST, PGDATABASE),"
  echo "  create a .pgmigrate file in the project root to map them:"
  echo ""
  echo "    DB_HOST=PGHOST"
  echo "    DB_PORT=PGPORT"
  echo "    DB_NAME=PGDATABASE"
  echo "    DB_USER=PGUSER"
  echo "    DB_PASSWORD=PGPASSWORD"
  echo ""
  echo "Install options (global install only):"
  echo "  pgmigrate uninstall           Remove pgmigrate from the system"
}
