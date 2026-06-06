#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# rotate.sh — Backup Rotation & Cleanup
# Removes old backups based on retention policy:
#   - Daily:  keep last N days
#   - Weekly: keep last N weeks (Sundays)
#   - Monthly: keep last N months (1st of month)
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/backup-config.sh"

DRY_RUN="${DRY_RUN:-false}"

log() { echo "[$(date '+%H:%M:%S')] $*"; }
do_rm() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    log "[DRY-RUN] Would delete: $1"
  else
    rm -rf "$1"
    log "Deleted: $1"
  fi
}

cd "${BACKUP_ROOT}"

log "═══════════════════════════════════════════"
log "Backup Rotation — $(date)"
log "Retention: daily=${RETENTION_DAILY} weekly=${RETENTION_WEEKLY} monthly=${RETENTION_MONTHLY}"
log "═══════════════════════════════════════════"

# Collect all backup date directories (YYYYMMDD)
declare -A kept_reasons

for dir in [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]/; do
  dir="${dir%/}"
  [[ -d "${dir}" ]] || continue

  # Extract date parts
  year="${dir:0:4}"
  month="${dir:4:2}"
  day="${dir:6:2}"
  date_str="${year}-${month}-${day}"
  dow="$(date -d "${date_str}" +%u 2>/dev/null || echo "")"
  dom="${day}"

  reason=""

  # Monthly: keep 1st of month
  if [[ "${dom}" == "01" ]]; then
    reason="monthly (1st)"
  # Weekly: keep Sundays (dow=7)
  elif [[ "${dow}" == "7" ]]; then
    reason="weekly (Sunday)"
  # Daily: keep last N days
  else
    age=$(( ($(date +%s) - $(date -d "${date_str}" +%s)) / 86400 ))
    if [[ ${age} -le ${RETENTION_DAILY} ]]; then
      reason="daily (${age}d old)"
    fi
  fi

  if [[ -n "${reason}" ]]; then
    kept_reasons["${dir}"]="${reason}"
  fi
done

# Now enforce limits: keep only N most recent of each category
for category in "monthly" "weekly" "daily"; do
  case "${category}" in
    monthly) limit="${RETENTION_MONTHLY}" ;;
    weekly)  limit="${RETENTION_WEEKLY}" ;;
    daily)   limit="${RETENTION_DAILY}" ;;
  esac

  # Get sorted (newest first) dirs in this category
  mapfile -t dirs < <(
    for d in "${!kept_reasons[@]}"; do
      [[ "${kept_reasons[$d]}" == "${category}"* ]] && echo "$d"
    done | sort -r
  )

  if [[ ${#dirs[@]} -le ${limit} ]]; then
    continue
  fi

  # Delete excess (oldest ones)
  for ((i = limit; i < ${#dirs[@]}; i++)); do
    d="${dirs[$i]}"
    log "Exceed ${category} limit (${limit}) — removing ${d}"
    do_rm "${d}"
    unset "kept_reasons[${d}]"
  done
done

log ""
log "Remaining backups after rotation:"
for d in $(printf "%s\n" "${!kept_reasons[@]}" | sort -r); do
  size="$(du -sh "${d}" 2>/dev/null | cut -f1)"
  log "  ${d} (${kept_reasons[$d]}, ${size})"
done

log "Rotation complete."
