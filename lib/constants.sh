#!/usr/bin/env bash
# =============================================================================
# Constants — terminal color codes
# Requires: SCRIPT_DIR to be set by the caller (migrate.sh)
#
# Note: MIGRATIONS_DIR and SCHEMAS_DIR are resolved in load_env (lib/helpers.sh)
# after the .env file is parsed, so they can be overridden by the user.
# =============================================================================

ENV_FILE="${PROJECT_DIR}/.env"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
