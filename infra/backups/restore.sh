#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# restore.sh — Restore from a backup snapshot
# ═══════════════════════════════════════════════════════════════
#
# Usage:
#   ./restore.sh list              # list available backups
#   ./restore.sh <YYYYMMDD> code   # restore git bundles
#   ./restore.sh <YYYYMMDD> db     # restore databases
#   ./restore.sh <YYYYMMDD> config # restore configs
#   ./restore.sh <YYYYMMDD> all    # restore everything (prompts)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/backup-config.sh"

log() { echo "[$(date '+%H:%M:%S')] $*"; }
err() { echo "ERROR: $*" >&2; }

confirm() {
  read -r -p "⚠  $* [y/N] " reply
  [[ "${reply,,}" == "y" ]]
}

list_backups() {
  echo "Available backups in ${BACKUP_ROOT}:"
  echo ""
  for dir in $(ls -1d "${BACKUP_ROOT}"/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9] 2>/dev/null | sort -r); do
    local name
    name="$(basename "${dir}")"
    local date_str="${name:0:4}-${name:4:2}-${name:6:2}"
    local count
    count="$(find "${dir}" -maxdepth 1 -type f | wc -l)"
    local size
    size="$(du -sh "${dir}" 2>/dev/null | cut -f1)"
    echo "  ${name}  (${date_str}) — ${count} files, ${size}"
    ls -lh "${dir}" 2>/dev/null | tail -n +2 | awk '{print "        " $5 "  " $NF}'
  done
}

restore_code() {
  local backup_dir="$1"
  log "Restoring code repositories..."
  for f in "${backup_dir}"/*.bundle; do
    [[ -f "${f}" ]] || continue
    local name
    name="$(basename "${f}" .bundle)"
    local restore_path="${BACKUP_TMP}/${name}"
    log "  Extracting ${name} to ${restore_path}..."
    git -C "${restore_path}" bundle verify "${f}" 2>/dev/null || {
      mkdir -p "${restore_path}"
      git -C "${restore_path}" init
    }
    git -C "${restore_path}" fetch "${f}" "+refs/heads/*:refs/remotes/origin/*" 2>/dev/null
    log "  Done. Restored to ${restore_path} (check out manually)"
  done
}

restore_db() {
  local backup_dir="$1"
  log "Restoring databases..."

  # SQLite
  local sqlite_backup="${backup_dir}/architect.db"
  if [[ -f "${sqlite_backup}" ]]; then
    if docker inspect "${SQLITE_CONTAINER}" >/dev/null 2>&1; then
      docker cp "${sqlite_backup}" "${SQLITE_CONTAINER}:${SQLITE_DB_PATH}" && \
        log "  SQLite restored to ${SQLITE_CONTAINER}"
    else
      log "  SQLite backup found at ${sqlite_backup} — container not running"
    fi
  fi

  # PostgreSQL
  local pg_backup="${backup_dir}/postgres_${PG_DB}.sql.gz"
  if [[ -f "${pg_backup}" ]]; then
    if docker inspect "${PG_CONTAINER}" >/dev/null 2>&1; then
      gunzip -c "${pg_backup}" | docker exec -i "${PG_CONTAINER}" \
        psql -U "${PG_USER}" "${PG_DB}" && \
        log "  PostgreSQL restored to ${PG_CONTAINER}"
    else
      log "  PostgreSQL backup found — container not running"
    fi
  fi
}

restore_config() {
  local backup_dir="$1"
  local config_archive="${backup_dir}/configs.tar.gz"
  if [[ -f "${config_archive}" ]]; then
    log "Configs stored in ${config_archive}"
    log "Extract: tar xzf ${config_archive} -C /"
    log "Review each file before applying."
  fi
}

main() {
  local backup_date="${1:-}"
  local mode="${2:-all}"

  if [[ "${backup_date}" == "list" ]]; then
    list_backups
    exit 0
  fi

  if [[ -z "${backup_date}" ]]; then
    echo "Usage: $0 list | <YYYYMMDD> {code|db|config|all}"
    exit 1
  fi

  local backup_dir="${BACKUP_ROOT}/${backup_date}"
  if [[ ! -d "${backup_dir}" ]]; then
    err "Backup not found: ${backup_dir}"
    list_backups
    exit 1
  fi

  log "Restoring from: ${backup_dir}"
  if [[ "${mode}" != "code" && "${mode}" != "all" ]]; then
    confirm "This will overwrite existing data. Continue?" || exit 1
  fi

  mkdir -p "${BACKUP_TMP}"

  case "${mode}" in
    code)   restore_code   "${backup_dir}" ;;
    db)     restore_db     "${backup_dir}" ;;
    config) restore_config "${backup_dir}" ;;
    all)
      restore_code   "${backup_dir}"
      restore_db     "${backup_dir}"
      restore_config "${backup_dir}"
      ;;
    *) echo "Unknown mode: ${mode}"; exit 1 ;;
  esac

  log "Restore complete."
}

main "$@"
