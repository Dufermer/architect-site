#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# backup.sh — Automated Backup for dunaev.dev
# Code repos, databases, configs, Docker volumes
# ═══════════════════════════════════════════════════════════════
#
# Usage:
#   ./backup.sh                 # full backup (default)
#   ./backup.sh code            # git repos only
#   ./backup.sh db              # databases only
#   ./backup.sh config          # configs only
#   ./backup.sh volumes         # Docker volumes only
#   ./backup.sh all             # full backup (same as no args)
#   ./backup.sh upload          # upload to S3/R2 only
#
# Schedule via cron (see cron/backup-cron)

set -euo pipefail

# ── Resolve script directory (works with symlinks) ────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/backup-config.sh"

# ── Date & stamp ──────────────────────────────────────────────
DATE_STAMP="$(date +%Y%m%d)"
TIME_STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/${DATE_STAMP}"
LOG_FILE="${BACKUP_ROOT}/logs/backup_${TIME_STAMP}.log"

# ── Ensure directories ────────────────────────────────────────
mkdir -p "${BACKUP_DIR}" "${BACKUP_TMP}" "${BACKUP_ROOT}/logs"

# ── Helpers ───────────────────────────────────────────────────
log()  { echo "[$(date '+%H:%M:%S')] $*" | tee -a "${LOG_FILE}"; }
err()  { log "ERROR: $*"; }
ok()   { log "OK: $*"; }
die()  { err "$*"; cleanup; exit 1; }

cleanup() {
  [[ -d "${BACKUP_TMP}" ]] && rm -rf "${BACKUP_TMP:?}"/*
  log "Cleanup done"
}

notify() {
  local status="$1"
  local msg="$2"
  if [[ -n "${WEBHOOK_URL}" ]]; then
    curl -fsS -m 10 -X POST "${WEBHOOK_URL}" \
      -H "Content-Type: application/json" \
      -d "{\"text\":\"[dunaev-backup] ${status}: ${msg}\"}" \
      >/dev/null 2>&1 || true
  fi
}

# ── 1. Backup Git Repositories (git bundle) ───────────────────
backup_code() {
  log "=== Backing up code repositories ==="
  local ok=true

  for repo_entry in "${REPOS[@]}"; do
    local repo_path="${repo_entry%%:*}"
    local bundle_name="${repo_entry##*:}"
    local bundle_file="${BACKUP_DIR}/${bundle_name}.bundle"

    if [[ ! -d "${repo_path}/.git" ]]; then
      err "Not a git repo: ${repo_path}"
      ok=false
      continue
    fi

    if git -C "${repo_path}" bundle create "${bundle_file}" --all HEAD 2>>"${LOG_FILE}"; then
      local size
      size="$(stat -c%s "${bundle_file}" 2>/dev/null || echo 0)"
      ok "Git bundle ${bundle_name} ($(numfmt --to=iec "${size}"))"
    else
      err "Failed to bundle ${repo_path}"
      ok=false
    fi
  done

  $ok && ok "Code backup complete" || err "Code backup had errors"
  $ok
}

# ── 2. Backup Databases ───────────────────────────────────────
backup_db() {
  log "=== Backing up databases ==="
  local ok=true

  # SQLite — via docker exec
  if docker inspect "${SQLITE_CONTAINER}" >/dev/null 2>&1; then
    local sqlite_out="${BACKUP_DIR}/architect.db"
    if docker exec "${SQLITE_CONTAINER}" \
      sqlite3 "${SQLITE_DB_PATH}" ".backup '${BACKUP_TMP}/architect.db'" 2>>"${LOG_FILE}"; then
      cp "${BACKUP_TMP}/architect.db" "${sqlite_out}"
      local size
      size="$(stat -c%s "${sqlite_out}" 2>/dev/null || echo 0)"
      ok "SQLite backup ($(numfmt --to=iec "${size}"))"
    else
      err "SQLite backup failed (container may be down)"
      ok=false
    fi
  else
    log "SQLite container '${SQLITE_CONTAINER}' not running — skipping"
  fi

  # PostgreSQL — via docker exec pg_dump
  if docker inspect "${PG_CONTAINER}" >/dev/null 2>&1; then
    local pg_out="${BACKUP_DIR}/postgres_${PG_DB}.sql.gz"
    if docker exec "${PG_CONTAINER}" \
      pg_dump -U "${PG_USER}" "${PG_DB}" 2>>"${LOG_FILE}" \
      | gzip > "${pg_out}"; then
      local size
      size="$(stat -c%s "${pg_out}" 2>/dev/null || echo 0)"
      ok "PostgreSQL dump ($(numfmt --to=iec "${size}"))"
    else
      err "PostgreSQL dump failed"
      ok=false
    fi
  else
    log "PostgreSQL container '${PG_CONTAINER}' not running — skipping"
  fi

  # Dump list of installed packages (OS-level)
  dpkg --get-selections > "${BACKUP_DIR}/packages.list" 2>/dev/null || true

  $ok && ok "Database backup complete" || err "Database backup had errors"
  $ok
}

# ── 3. Backup Configs ─────────────────────────────────────────
backup_config() {
  log "=== Backing up configuration files ==="
  local config_archive="${BACKUP_DIR}/configs.tar.gz"
  local paths_to_archive=()

  for p in "${CONFIG_PATHS[@]}"; do
    if [[ -e "${p}" ]]; then
      # Map absolute paths to relative names in the archive
      local rel_name="${p#/}"
      rel_name="${rel_name//\//_}"
      # Copy to temp with safe name
      if [[ -d "${p}" ]]; then
        cp -a "${p}" "${BACKUP_TMP}/config_${rel_name}" 2>/dev/null || true
      elif [[ -f "${p}" ]]; then
        cp -a "${p}" "${BACKUP_TMP}/config_${rel_name}" 2>/dev/null || true
      fi
    fi
  done

  # Also capture env vars that matter
  env | grep -E '^(PG_|CORS_|S3_|AWS_|DUN_)' > "${BACKUP_TMP}/env_snapshot.txt" 2>/dev/null || true

  # Package everything
  (cd "${BACKUP_TMP}" && tar czf "${config_archive}" config_* env_snapshot.txt 2>/dev/null) || true

  if [[ -f "${config_archive}" ]]; then
    local size
    size="$(stat -c%s "${config_archive}" 2>/dev/null || echo 0)"
    ok "Config archive ($(numfmt --to=iec "${size}"))"
    return 0
  else
    err "Config archive creation failed"
    return 1
  fi
}

# ── 4. Backup Docker Volumes ──────────────────────────────────
backup_volumes() {
  log "=== Backing up Docker volumes ==="
  local ok=true

  for vol_entry in "${DOCKER_VOLUMES[@]}"; do
    local vol_name="${vol_entry%%:*}"
    local vol_label="${vol_entry##*:}"
    local vol_path="/var/lib/docker/volumes/${vol_name}/_data"
    local vol_archive="${BACKUP_DIR}/volume_${vol_label}.tar.gz"

    if [[ -d "${vol_path}" ]]; then
      if tar czf "${vol_archive}" -C "${vol_path}" . 2>>"${LOG_FILE}"; then
        local size
        size="$(stat -c%s "${vol_archive}" 2>/dev/null || echo 0)"
        ok "Volume ${vol_label} ($(numfmt --to=iec "${size}"))"
      else
        err "Failed to archive volume ${vol_label}"
        ok=false
      fi
    else
      log "Volume path not found: ${vol_path} — skipping"
    fi
  done

  $ok && ok "Volume backup complete" || err "Volume backup had errors"
  $ok
}

# ── 5. Upload to S3 / R2 ──────────────────────────────────────
upload_backup() {
  if [[ -z "${S3_ENDPOINT}" || -z "${AWS_ACCESS_KEY_ID}" ]]; then
    log "S3/R2 not configured — skipping upload"
    return 0
  fi

  log "=== Uploading to S3/R2 ==="
  local ok=true

  # Check for s3cmd or aws-cli
  local s3_cmd=""
  if command -v aws &>/dev/null; then
    s3_cmd="aws s3"
  elif command -v s3cmd &>/dev/null; then
    s3_cmd="s3cmd"
  else
    err "No S3 client (aws-cli or s3cmd) installed"
    return 1
  fi

  local remote_path="s3://${S3_BUCKET}/backups/$(hostname)/${DATE_STAMP}/"

  if [[ "${s3_cmd}" == "aws s3" ]]; then
    AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
    AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
    aws s3 sync "${BACKUP_DIR}" "${remote_path}" \
      --endpoint-url "${S3_ENDPOINT}" \
      --region "${S3_REGION}" \
      2>>"${LOG_FILE}" && ok "Uploaded to S3/R2" || { err "S3 upload failed"; ok=false; }
  else
    s3cmd --access_key="${AWS_ACCESS_KEY_ID}" \
      --secret_key="${AWS_SECRET_ACCESS_KEY}" \
      --host="${S3_ENDPOINT}" \
      --host-bucket="${S3_BUCKET}" \
      sync "${BACKUP_DIR}/" "s3://${S3_BUCKET}/backups/$(hostname)/${DATE_STAMP}/" \
      2>>"${LOG_FILE}" && ok "Uploaded via s3cmd" || { err "s3cmd upload failed"; ok=false; }
  fi

  $ok
}

# ── 6. Backup Summary ─────────────────────────────────────────
print_summary() {
  log ""
  log "═══════════════════════════════════════════"
  log "Backup Summary — ${TIME_STAMP}"
  log "═══════════════════════════════════════════"
  log "Destination: ${BACKUP_DIR}"
  find "${BACKUP_DIR}" -maxdepth 1 -type f -exec ls -lh {} \; 2>/dev/null \
    | awk '{print "  " $5 "  " $NF}' \
    | tee -a "${LOG_FILE}"
  log "Total size: $(du -sh "${BACKUP_DIR}" 2>/dev/null | cut -f1)"
  log "═══════════════════════════════════════════"
}

# ── Main ──────────────────────────────────────────────────────
main() {
  local mode="${1:-all}"
  local exit_code=0

  log "═══════════════════════════════════════════"
  log "dunaev Backup — ${TIME_STAMP}"
  log "Mode: ${mode}"
  log "═══════════════════════════════════════════"

  case "${mode}" in
    code)
      backup_code || exit_code=1
      ;;
    db)
      backup_db || exit_code=1
      ;;
    config)
      backup_config || exit_code=1
      ;;
    volumes)
      backup_volumes || exit_code=1
      ;;
    upload)
      upload_backup || exit_code=1
      ;;
    all|"")
      backup_code    || exit_code=1
      backup_db      || exit_code=1
      backup_config  || exit_code=1
      backup_volumes || exit_code=1
      upload_backup  || true  # upload failure is non-fatal
      ;;
    *)
      echo "Usage: $0 {code|db|config|volumes|upload|all}"
      exit 1
      ;;
  esac

  print_summary
  cleanup

  if [[ ${exit_code} -eq 0 ]]; then
    notify "SUCCESS" "Backup completed — ${BACKUP_DIR}"
    log "Backup SUCCESS"
  else
    notify "FAILURE" "Backup completed with errors — ${LOG_FILE}"
    log "Backup COMPLETED WITH ERRORS (see log)"
  fi

  return ${exit_code}
}

main "$@"
