#!/usr/bin/env bash
# =============================================================================
# Helpers — logging, .env loading, checksum, migration file parsing
# =============================================================================

# ---- Logging ----------------------------------------------------------------

log_info()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ---- Environment ------------------------------------------------------------

load_env() {
  if [[ ! -f "$ENV_FILE" ]]; then
    log_error ".env file not found at ${ENV_FILE}"
    log_info "Create one with the following variables:"
    echo ""
    echo "  DB_HOST=localhost"
    echo "  DB_PORT=5432"
    echo "  DB_NAME=myapp"
    echo "  DB_USER=postgres"
    echo "  DB_PASSWORD=secret"
    echo ""
    exit 1
  fi

  # Export variables from .env (skip comments and empty lines)
  set -a
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    # Remove surrounding quotes from value
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"
    export "$key=$value"
  done < "$ENV_FILE"
  set +a

  for var in DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD; do
    if [[ -z "${!var:-}" ]]; then
      log_error "Missing required variable: ${var} in .env"
      exit 1
    fi
  done

  # Resolve paths — use .env overrides if provided, otherwise default to
  # directories next to migrate.sh
  MIGRATIONS_DIR="${MIGRATIONS_DIR:-${PROJECT_DIR}/migrations}"
  SCHEMAS_DIR="${SCHEMAS_DIR:-${PROJECT_DIR}/schemas}"

  # Check required system dependency
  if ! command -v psql &>/dev/null; then
    log_error "psql is not installed or not in PATH."
    log_info  "Install PostgreSQL client tools and make sure psql is available."
    exit 1
  fi
}

# ---- Checksum ---------------------------------------------------------------

# Compute a SHA-256 checksum over the UP section of a migration file
compute_checksum() {
  local file="$1"
  if command -v sha256sum &>/dev/null; then
    extract_up "$file" | sha256sum | awk '{print $1}'
  else
    extract_up "$file" | shasum -a 256 | awk '{print $1}'
  fi
}

# ---- Migration File Parsing -------------------------------------------------

# Extract the SQL between "-- UP" and "-- DOWN" markers
extract_up() {
  local file="$1"
  sed -n '/^-- UP[[:space:]]*$/,/^-- DOWN[[:space:]]*$/{ /^-- UP[[:space:]]*$/d; /^-- DOWN[[:space:]]*$/d; p; }' "$file"
}

# Extract the SQL after the "-- DOWN" marker
extract_down() {
  local file="$1"
  sed -n '/^-- DOWN[[:space:]]*$/,$ { /^-- DOWN[[:space:]]*$/d; p; }' "$file"
}
