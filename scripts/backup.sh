#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Automated Backup Script — DUN-104
# Code, Databases, Configs
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

# ── Configuration ──────────────────────────────────────────────
BACKUP_ROOT="${BACKUP_ROOT:-/home/i/backups}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"
LOG_FILE="${BACKUP_ROOT}/backup.log"

# Repos to backup (git bundle)
REPOS=(
  "/home/i/.hermes"
  "/home/i/.hermes/hermes-agent"
  "/home/i/Проекты/dunaev"
  "/home/i/Проекты/zapret-discord-youtube-linux"
  "/home/i/Проекты/maledictum"
  "/home/i/zapret-discord-youtube-linux"
  "/home/i/comfy/ComfyUI"
)

# SQLite databases to backup
SQLITE_DBS=(
  "/home/i/.paperclip/instances/default/projects/7c1f2d87-dfe6-41f6-b48d-03e616548709/47a590ce-abaa-40aa-af5f-361b5a236b2d/_default/onboarding.db"
)

# Config directories/files to backup
CONFIG_PATHS=(
  "/home/i/.hermes/config.yaml"
  "/home/i/.hermes/.env"
  "/home/i/.config/alacritty/alacritty.toml"
  "/home/i/.ssh"
  "/home/i/.gitconfig"
)

# Paperclip project dirs to rsync
PAPERCLIP_PROJECTS=(
  "/home/i/.paperclip/instances/default/projects"
)

# ── Setup ──────────────────────────────────────────────────────
mkdir -p "$BACKUP_ROOT" "$BACKUP_DIR"

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$msg"
  echo "$msg" >> "$LOG_FILE"
}

log "=== Backup started: $TIMESTAMP ==="

# ── 1. Git Repos (bundle) ─────────────────────────────────────
log "--- Step 1/5: Backing up Git repos (bundle) ---"
GIT_DIR="${BACKUP_DIR}/git"
mkdir -p "$GIT_DIR"

for repo in "${REPOS[@]}"; do
  if [ -d "$repo/.git" ]; then
    repo_name="$(basename "$repo")"
    bundle_file="${GIT_DIR}/${repo_name}.bundle"
    log "  Bundling: $repo → $bundle_file"
    git -C "$repo" bundle create "$bundle_file" --all 2>>"$LOG_FILE" || log "  ⚠ Failed to bundle $repo"
  else
    log "  ⚠ Skipping (no .git): $repo"
  fi
done

# ── 2. SQLite Databases ───────────────────────────────────────
log "--- Step 2/5: Backing up SQLite databases ---"
SQLITE_DIR="${BACKUP_DIR}/sqlite"
mkdir -p "$SQLITE_DIR"

for db in "${SQLITE_DBS[@]}"; do
  if [ -f "$db" ]; then
    db_name="$(basename "$db")"
    backup_file="${SQLITE_DIR}/${db_name}"
    log "  Backing up: $db → $backup_file"
    sqlite3 "$db" ".backup '$backup_file'" 2>>"$LOG_FILE" || log "  ⚠ sqlite3 backup failed for $db"
    # Also dump as SQL for portability
    sqlite3 "$db" ".dump" > "${backup_file}.sql" 2>>"$LOG_FILE" || log "  ⚠ sqlite3 dump failed for $db"
  else
    log "  ⚠ Not found: $db"
  fi
done

# ── 3. Config Files ───────────────────────────────────────────
log "--- Step 3/5: Backing up config files ---"
CONFIG_DIR="${BACKUP_DIR}/configs"
mkdir -p "$CONFIG_DIR"

for cfg in "${CONFIG_PATHS[@]}"; do
  if [ -e "$cfg" ]; then
    dest="$CONFIG_DIR/$(echo "$cfg" | sed 's|^/||; s|/|_|g')"
    log "  Copying: $cfg → $dest"
    cp -a "$cfg" "$dest"
  else
    log "  ⚠ Not found: $cfg"
  fi
done

# ── 4. Paperclip Projects ─────────────────────────────────────
log "--- Step 4/5: Backing up Paperclip project data ---"
PAPERCLIP_DIR="${BACKUP_DIR}/paperclip"
mkdir -p "$PAPERCLIP_DIR"

for project_dir in "${PAPERCLIP_PROJECTS[@]}"; do
  if [ -d "$project_dir" ]; then
    project_name="$(basename "$(dirname "$project_dir")")"
    log "  Rsyncing: $project_dir → ${PAPERCLIP_DIR}/${project_name}/"
    rsync -a --exclude='node_modules' --exclude='.git' "$project_dir" "${PAPERCLIP_DIR}/${project_name}/" 2>>"$LOG_FILE" || log "  ⚠ rsync failed for $project_dir"
  fi
done

# ── 5. Optional: S3/R2 Upload ─────────────────────────────────
if [ -n "${R2_ENDPOINT:-}" ] && [ -n "${R2_ACCESS_KEY:-}" ] && [ -n "${R2_SECRET_KEY:-}" ] && [ -n "${R2_BUCKET:-}" ]; then
  log "--- Step 5/5: Uploading to Cloudflare R2 ---"
  # Using aws CLI for S3-compatible storage
  if command -v aws &>/dev/null; then
    AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY" \
    AWS_SECRET_ACCESS_KEY="$R2_SECRET_KEY" \
    aws s3 sync "$BACKUP_DIR" "s3://${R2_BUCKET}/backups/${TIMESTAMP}/" \
      --endpoint-url "$R2_ENDPOINT" \
      --region auto 2>>"$LOG_FILE" && log "  ✅ Uploaded to R2" || log "  ⚠ R2 upload failed"
  else
    log "  ⚠ aws CLI not installed, skipping R2 upload"
  fi
else
  log "--- Step 5/5: Skipped (R2 not configured) ---"
fi

# ── Summary ────────────────────────────────────────────────────
log "=== Backup complete: $TIMESTAMP ==="
log "  Location: $BACKUP_DIR"
du -sh "$BACKUP_DIR" >> "$LOG_FILE"

echo ""
echo "✅ Backup complete!"
echo "   Location: $BACKUP_DIR"
echo "   Size: $(du -sh "$BACKUP_DIR" | cut -f1)"
echo ""
