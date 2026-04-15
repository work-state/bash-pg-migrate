#!/usr/bin/env bash
# =============================================================================
# pgmigrate installer
#
# Usage:
#   ./install.sh                      Install to /usr/local (default)
#   ./install.sh --prefix ~/.local    Install to a custom prefix
#   ./install.sh --uninstall          Remove a previously installed pgmigrate
#   ./install.sh --help               Show usage
#
# Supported platforms:
#   macOS (Darwin)   — Bash 4+ recommended (macOS ships with Bash 3.2)
#   Linux            — Ubuntu, Debian, CentOS, Arch, and others
#   WSL              — Windows Subsystem for Linux (treated as Linux)
#
# Not supported:
#   Windows native, Git Bash, Cygwin — use WSL instead
# =============================================================================

set -euo pipefail

# ---- Defaults ---------------------------------------------------------------

PREFIX="/usr/local"
UNINSTALL=false
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolved after argument parsing
LIB_DIR=""
BIN_FILE=""

# ---- Colors (inline — installer runs before lib/ is available) --------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()    { echo -e "${CYAN}[....] ${NC} $1"; }

# ---- Argument parsing -------------------------------------------------------

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prefix)
        PREFIX="${2:?--prefix requires a value}"
        shift 2
        ;;
      --uninstall)
        UNINSTALL=true
        shift
        ;;
      -h|--help)
        echo "Usage: ./install.sh [--prefix <dir>] [--uninstall]"
        echo ""
        echo "  --prefix <dir>   Installation prefix (default: /usr/local)"
        echo "  --uninstall      Remove pgmigrate from the given prefix"
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        echo "Run './install.sh --help' for usage."
        exit 1
        ;;
    esac
  done

  LIB_DIR="${PREFIX}/lib/pgmigrate"
  BIN_FILE="${PREFIX}/bin/pgmigrate"
}

# ---- OS Detection -----------------------------------------------------------

detect_os() {
  local os
  os="$(uname -s 2>/dev/null || echo "unknown")"

  case "$os" in
    Darwin) echo "macos" ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
      else
        echo "linux"
      fi
      ;;
    MINGW*|CYGWIN*|MSYS*) echo "windows" ;;
    *) echo "unsupported" ;;
  esac
}

# ---- System info ------------------------------------------------------------

# Print a structured overview of the environment being installed into
system_info() {
  local os="$1"

  echo ""
  echo -e "${BOLD}System Information${NC}"
  echo "  OS           : ${os}"
  echo "  Bash version : ${BASH_VERSION}"
  echo "  Install dir  : ${LIB_DIR}"
  echo "  Launcher     : ${BIN_FILE}"

  local psql_version pg_dump_version
  psql_version=$(psql --version 2>/dev/null || echo "not found")
  pg_dump_version=$(pg_dump --version 2>/dev/null || echo "not found")
  echo "  psql         : ${psql_version}"
  echo "  pg_dump      : ${pg_dump_version}"
  echo ""
}

# ---- Dependency checks ------------------------------------------------------

check_dependencies_macos() {
  log_step "Checking dependencies..."

  local missing=()
  for cmd in psql pg_dump; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_warn "Missing dependencies: ${missing[*]}"
    log_info "Install them with Homebrew:"
    echo ""
    echo "    brew install postgresql"
    echo ""
    log_warn "pgmigrate is installed but will not work until the above is resolved."
  else
    log_success "All dependencies found."
  fi
}

check_dependencies_linux() {
  log_step "Checking dependencies..."

  local missing=()
  for cmd in psql pg_dump; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_warn "Missing dependencies: ${missing[*]}"
    log_info "Install them with your package manager:"
    echo ""
    echo "    # Debian / Ubuntu"
    echo "    sudo apt-get install postgresql-client"
    echo ""
    echo "    # CentOS / RHEL / Fedora"
    echo "    sudo dnf install postgresql"
    echo ""
    echo "    # Arch"
    echo "    sudo pacman -S postgresql-libs"
    echo ""
    log_warn "pgmigrate is installed but will not work until the above is resolved."
  else
    log_success "All dependencies found."
  fi
}

# ---- Bash version check (macOS only) ----------------------------------------

check_bash_version_macos() {
  local major="${BASH_VERSINFO[0]}"

  if [[ "$major" -lt 4 ]]; then
    log_warn "Bash ${BASH_VERSION} detected — Bash 4+ is recommended."
    log_info "macOS ships with Bash 3.2 due to licensing. Upgrade via Homebrew:"
    echo ""
    echo "    brew install bash"
    echo ""
    echo "    # Then add the new shell to the allowed list:"
    echo "    sudo bash -c 'echo /opt/homebrew/bin/bash >> /etc/shells'"
    echo "    chsh -s /opt/homebrew/bin/bash"
    echo ""
    log_warn "pgmigrate may still work on Bash 3.2 but Bash 4+ is recommended."
  else
    log_success "Bash ${BASH_VERSION} — OK."
  fi
}

# ---- Copy library (shared) --------------------------------------------------

copy_library() {
  log_step "Copying library files to ${LIB_DIR}..."

  mkdir -p "${LIB_DIR}/lib"
  mkdir -p "${LIB_DIR}/commands"

  cp "${REPO_DIR}/migrate.sh"           "${LIB_DIR}/migrate.sh"
  cp "${REPO_DIR}/lib/constants.sh"     "${LIB_DIR}/lib/constants.sh"
  cp "${REPO_DIR}/lib/helpers.sh"       "${LIB_DIR}/lib/helpers.sh"
  cp "${REPO_DIR}/lib/db.sh"            "${LIB_DIR}/lib/db.sh"
  cp "${REPO_DIR}/lib/snapshot.sh"      "${LIB_DIR}/lib/snapshot.sh"
  cp "${REPO_DIR}/commands/help.sh"     "${LIB_DIR}/commands/help.sh"
  cp "${REPO_DIR}/commands/up.sh"       "${LIB_DIR}/commands/up.sh"
  cp "${REPO_DIR}/commands/down.sh"     "${LIB_DIR}/commands/down.sh"
  cp "${REPO_DIR}/commands/status.sh"   "${LIB_DIR}/commands/status.sh"
  cp "${REPO_DIR}/commands/create.sh"   "${LIB_DIR}/commands/create.sh"
  cp "${REPO_DIR}/commands/snapshot.sh" "${LIB_DIR}/commands/snapshot.sh"

  chmod +x "${LIB_DIR}/migrate.sh"

  log_success "Library installed to ${LIB_DIR}"
}

# ---- Inject launcher into bin -----------------------------------------------

inject_bin() {
  log_step "Installing launcher at ${BIN_FILE}..."

  if [[ ! -d "${PREFIX}/bin" ]]; then
    log_error "Target bin directory does not exist: ${PREFIX}/bin"
    log_info  "Create it first or choose a different --prefix."
    exit 1
  fi

  if [[ ! -w "${PREFIX}/bin" ]]; then
    log_error "No write permission to ${PREFIX}/bin"
    log_info  "Re-run with elevated privileges:"
    echo ""
    echo "    sudo ./install.sh"
    if [[ "$PREFIX" != "/usr/local" ]]; then
      echo "    sudo ./install.sh --prefix ${PREFIX}"
    fi
    echo ""
    exit 1
  fi

  cat > "${BIN_FILE}" <<EOF
#!/usr/bin/env bash
# pgmigrate launcher — auto-generated by install.sh
if [[ "\${1:-}" == "uninstall" ]]; then
  echo "Uninstalling pgmigrate..."
  rm -rf "${LIB_DIR}" && echo "[OK]  Removed ${LIB_DIR}"
  rm -f  "${BIN_FILE}" && echo "[OK]  Removed ${BIN_FILE}"
  echo "[OK]  pgmigrate uninstalled."
  exit 0
fi
exec "${LIB_DIR}/migrate.sh" "\$@"
EOF

  chmod +x "${BIN_FILE}"
  log_success "Launcher installed at ${BIN_FILE}"
}

# ---- Post-install summary ---------------------------------------------------

post_install_info() {
  local os="$1"

  echo ""
  echo -e "${BOLD}${GREEN}pgmigrate installed successfully.${NC}"
  echo ""

  # PATH check
  if [[ ":${PATH}:" != *":${PREFIX}/bin:"* ]]; then
    log_warn "${PREFIX}/bin is not in your PATH."
    echo ""

    case "$os" in
      macos)
        echo "  Add this line to ~/.zshrc (or ~/.bash_profile if using Bash):"
        ;;
      linux|wsl)
        echo "  Add this line to ~/.bashrc (or ~/.zshrc if using Zsh):"
        ;;
    esac

    echo ""
    echo "    export PATH=\"${PREFIX}/bin:\$PATH\""
    echo ""
    echo "  Then reload your shell:"
    echo ""

    case "$os" in
      macos)    echo "    source ~/.zshrc" ;;
      linux|wsl) echo "    source ~/.bashrc" ;;
    esac

    echo ""
  fi

  echo "  To get started in a project:"
  echo ""
  echo "    cd your-project/"
  echo "    cp .env.example .env    # fill in your DB credentials"
  echo "    pgmigrate help"
  echo ""
  echo "  To uninstall:"
  echo ""
  echo "    pgmigrate uninstall"
  echo ""
}

# ---- Uninstall (shared) -----------------------------------------------------

run_uninstall() {
  log_info "Uninstalling pgmigrate from ${PREFIX}..."
  echo ""

  if [[ -d "$LIB_DIR" ]]; then
    if [[ ! -w "$LIB_DIR" ]]; then
      log_error "No write permission to ${LIB_DIR}"
      log_info  "Re-run with elevated privileges: sudo ./install.sh --uninstall"
      exit 1
    fi
    rm -rf "$LIB_DIR"
    log_success "Removed ${LIB_DIR}"
  else
    log_warn "${LIB_DIR} not found — skipping."
  fi

  if [[ -f "$BIN_FILE" ]]; then
    if [[ ! -w "$BIN_FILE" ]]; then
      log_error "No write permission to ${BIN_FILE}"
      log_info  "Re-run with elevated privileges: sudo ./install.sh --uninstall"
      exit 1
    fi
    rm -f "$BIN_FILE"
    log_success "Removed ${BIN_FILE}"
  else
    log_warn "${BIN_FILE} not found — skipping."
  fi

  echo ""
  log_success "pgmigrate uninstalled."
}

# ---- OS-specific install entry points ---------------------------------------

install_macos() {
  echo -e "${BOLD}Installing pgmigrate on macOS...${NC}"
  echo ""
  check_bash_version_macos
  check_dependencies_macos
  copy_library
  inject_bin
  post_install_info "macos"
}

install_linux() {
  echo -e "${BOLD}Installing pgmigrate on Linux...${NC}"
  echo ""
  check_dependencies_linux
  copy_library
  inject_bin
  post_install_info "linux"
}

install_wsl() {
  echo -e "${BOLD}Installing pgmigrate on WSL (Windows Subsystem for Linux)...${NC}"
  echo ""
  log_info "WSL detected — using Linux installation path."
  echo ""
  check_dependencies_linux
  copy_library
  inject_bin
  post_install_info "wsl"
}

# ---- Main -------------------------------------------------------------------

main() {
  parse_args "$@"

  local os
  os=$(detect_os)

  # Hard block on unsupported platforms
  case "$os" in
    windows)
      echo ""
      log_error "Windows native is not supported."
      echo ""
      log_info  "pgmigrate requires Bash, psql, and a POSIX filesystem."
      log_info  "Use Windows Subsystem for Linux (WSL) instead:"
      echo ""
      echo "    1. Install WSL: https://aka.ms/wsl"
      echo "    2. Open a WSL terminal"
      echo "    3. Re-run: ./install.sh"
      echo ""
      exit 1
      ;;
    unsupported)
      log_error "Unsupported operating system: $(uname -s)"
      exit 1
      ;;
  esac

  system_info "$os"

  if [[ "$UNINSTALL" == true ]]; then
    run_uninstall
    exit 0
  fi

  case "$os" in
    macos) install_macos ;;
    linux) install_linux ;;
    wsl)   install_wsl   ;;
  esac
}

main "$@"
