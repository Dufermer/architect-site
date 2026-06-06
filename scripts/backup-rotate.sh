#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Backup Rotation Script — DUN-104
# Deletes backups older than RETENTION_DAYS
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

BACKUP_ROOT="${BACKUP_ROOT:-/home/i/backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
LOG_FILE="${BACKUP_ROOT}/rotation.log"

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$msg"
  echo "$msg" >> "$LOG_FILE"
}

log "=== Rotation started ==="
log "  Root:     $BACKUP_ROOT"
log "  Retain:   $RETENTION_DAYS days"

if [ ! -d "$BACKUP_ROOT" ]; then
  log "  Backup root does not exist, nothing to rotate."
  exit 0
fi

# List all timestamp-named directories
count=0
saved=0
for dir in "$BACKUP_ROOT"/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_*/; do
  [ -d "$dir" ] || continue
  dirname="$(basename "$dir")"
  # Parse YYYYMMDD
  date_part="${dirname%%_*}"
  if [ "${#date_part}" -ne 8 ]; then
    log "  ⚠ Skipping non-standard dir: $dirname"
    continue
  fi

  dir_epoch="$(date -d "${date_part}" +%s 2>/dev/null)" || { log "  ⚠ Cannot parse date: $date_part"; continue; }
  cutoff_epoch="$(date -d "-${RETENTION_DAYS} days" +%s)"
  
  if [ "$dir_epoch" -lt "$cutoff_epoch" ]; then
    size="$(du -sh "$dir" 2>/dev/null | cut -f1)"
    log "  Deleting old backup: $dirname (${size})"
    rm -rf "$dir"
    count=$(( count + 1 ))
  else
    saved=$(( saved + 1 ))
  fi
done

log "=== Rotation complete: deleted $count, kept $saved ==="
echo ""
echo "✅ Rotation complete: deleted $count backup(s), kept $saved"
echo ""
