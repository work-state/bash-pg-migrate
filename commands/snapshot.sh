#!/usr/bin/env bash
# =============================================================================
# Command: snapshot — regenerate schemas/ snapshots from the live database
# =============================================================================

cmd_snapshot() {
  ensure_database
  check_connection
  log_info "Generating schema snapshots..."
  generate_schema_snapshot
  log_success "Schema snapshots updated in ${SCHEMAS_DIR}"
}
