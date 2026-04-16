#!/usr/bin/env bash
# =============================================================================
# Test runner for pgmigrate
#
# Usage:
#   ./run_tests.sh                Run all tests
#   ./run_tests.sh tests/up.bats  Run a single test file
#   ./run_tests.sh --tap          Run all tests with TAP output
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="${SCRIPT_DIR}/tests"

# ---- Colours ----------------------------------------------------------------

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ---- Locate bats ------------------------------------------------------------

find_bats() {
  if command -v bats &>/dev/null; then
    echo "bats"
    return
  fi

  echo ""
}

BATS=$(find_bats)

if [[ -z "$BATS" ]]; then
  echo -e "${RED}[ERROR]${NC} bats-core is not installed."
  echo ""
  echo "  Install it with one of:"
  echo ""
  echo "    # macOS"
  echo "    brew install bats-core"
  echo ""
  echo "    # Debian / Ubuntu"
  echo "    sudo apt-get install bats"
  echo ""
  echo "    # npm (any platform)"
  echo "    npm install -g bats"
  echo ""
  exit 1
fi

# ---- Parse arguments --------------------------------------------------------

BATS_ARGS=()
TARGET=""

for arg in "$@"; do
  case "$arg" in
    --tap)     BATS_ARGS+=("--formatter" "tap") ;;
    --pretty)  BATS_ARGS+=("--formatter" "pretty") ;;
    -*)        BATS_ARGS+=("$arg") ;;
    *)         TARGET="$arg" ;;
  esac
done

# ---- Run --------------------------------------------------------------------

if [[ -n "$TARGET" ]]; then
  echo -e "${BLUE}Running:${NC} ${TARGET}"
  echo ""
  exec "$BATS" ${BATS_ARGS[@]+"${BATS_ARGS[@]}"} "$TARGET"
else
  echo -e "${BLUE}Running all tests in tests/${NC}"
  echo ""
  exec "$BATS" ${BATS_ARGS[@]+"${BATS_ARGS[@]}"} \
    "${TESTS_DIR}/env.bats" \
    "${TESTS_DIR}/connection.bats" \
    "${TESTS_DIR}/up.bats" \
    "${TESTS_DIR}/down.bats" \
    "${TESTS_DIR}/status.bats" \
    "${TESTS_DIR}/create.bats" \
    "${TESTS_DIR}/snapshot.bats"
fi
