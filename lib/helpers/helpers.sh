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

# Locate .env or the first .env.* file in the given directory.
# Prints the path and returns 0, or returns 1 if nothing is found.
find_env_file() {
  local dir="$1"

  [[ -f "${dir}/.env" ]] && { echo "${dir}/.env"; return 0; }

  local files=()
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find "$dir" -maxdepth 1 -name '.env.*' -type f -print0 2>/dev/null | sort -z)

  if [[ ${#files[@]} -gt 0 ]]; then
    if [[ ${#files[@]} -gt 1 ]]; then
      log_warn "Multiple .env.* files found. Using: $(basename "${files[0]}")"
    fi
    echo "${files[0]}"
    return 0
  fi

  return 1
}

# Read .pgmigrate mapping file and re-export internal variable names.
# Format: INTERNAL_VAR=SOURCE_VAR_IN_ENV
apply_env_mapping() {
  local config_file="${PROJECT_DIR}/.pgmigrate"
  [[ ! -f "$config_file" ]] && return 0

  while IFS='=' read -r target source || [[ -n "$target" ]]; do
    [[ -z "$target" || "$target" =~ ^[[:space:]]*# ]] && continue
    target=$(echo "$target" | xargs)
    source=$(echo "$source" | xargs)
    [[ -z "$source" ]] && continue
    if [[ -n "${!source:-}" ]]; then
      export "${target}=${!source}"
    fi
  done < "$config_file"
}

load_env() {
  local env_file
  env_file=$(find_env_file "$PROJECT_DIR") || {
    log_error "No .env file found in ${PROJECT_DIR}"
    log_info  "Accepted filenames: .env, .env.local, .env.development, .env.*"
    echo ""
    echo "  Option 1 — create a standard .env file:"
    echo ""
    echo "    DB_HOST=localhost"
    echo "    DB_PORT=5432"
    echo "    DB_NAME=myapp"
    echo "    DB_USER=postgres"
    echo "    DB_PASSWORD=secret"
    echo ""
    echo "  Option 2 — if your .env already uses different variable names,"
    echo "  create a .pgmigrate mapping file that tells pgmigrate which"
    echo "  variables to use:"
    echo ""
    echo "    DB_HOST=PGHOST"
    echo "    DB_PORT=PGPORT"
    echo "    DB_NAME=PGDATABASE"
    echo "    DB_USER=PGUSER"
    echo "    DB_PASSWORD=PGPASSWORD"
    echo ""
    exit 1
  }

  ENV_FILE="$env_file"

  if [[ "$(basename "$ENV_FILE")" != ".env" ]]; then
    log_info "Using env file: $(basename "$ENV_FILE")"
  fi

  # Export variables from env file (skip comments and empty lines)
  set -a
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
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

  # Apply .pgmigrate variable name mappings if present
  apply_env_mapping

  local missing=()
  for var in DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD; do
    [[ -z "${!var:-}" ]] && missing+=("$var")
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    for var in "${missing[@]}"; do
      log_error "Missing required variable: ${var}"
    done
    if [[ -f "${PROJECT_DIR}/.pgmigrate" ]]; then
      log_info "Check your .pgmigrate mapping file — the above variables may not be mapped correctly."
    else
      log_info "Add the above variables to your env file, or create a .pgmigrate mapping file."
      log_info "Run 'pgmigrate help' for more information."
    fi
    exit 1
  fi

  # Schema — default to public if not specified
  DB_SCHEMA="${DB_SCHEMA:-public}"

  # Resolve paths — use env overrides if provided, otherwise default to
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
