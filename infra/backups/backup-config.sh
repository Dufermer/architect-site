#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Backup Configuration — dunaev.dev
# Source this file from backup.sh or use as standalone defaults
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

# ── Base directories ──────────────────────────────────────────
BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/dunaev}"
BACKUP_TMP="${BACKUP_TMP:-/tmp/dunaev-backup}"
RETENTION_DAILY="${RETENTION_DAILY:-7}"      # keep 7 daily
RETENTION_WEEKLY="${RETENTION_WEEKLY:-4}"     # keep 4 weekly
RETENTION_MONTHLY="${RETION_MONTHLY:-3}"      # keep 3 monthly

# ── Project root (where docker-compose lives) ─────────────────
PROJECT_DIR="${PROJECT_DIR:-/root/dunaev}"

# ── Source repositories (git bundle) ──────────────────────────
REPOS=(
  "/root/dunaev:site-dunaev"
  "/home/i/Проекты/architect-site:site-architect"
)

# ── Docker Compose project ────────────────────────────────────
COMPOSE_FILE="${PROJECT_DIR}/infra/docker-compose.yml"
COMPOSE_PROJECT="${COMPOSE_PROJECT:-dunaev}"

# ── Databases ──────────────────────────────────────────────────
# SQLite (mounted volume path inside backend container)
SQLITE_CONTAINER="${SQLITE_CONTAINER:-architect-api}"
SQLITE_DB_PATH="${SQLITE_DB_PATH:-/data/architect.db}"

# PostgreSQL (optional)
PG_CONTAINER="${PG_CONTAINER:-architect-postgres}"
PG_DB="${PG_DB:-architect}"
PG_USER="${PG_USER:-architect}"

# ── Config paths to capture ───────────────────────────────────
CONFIG_PATHS=(
  "${PROJECT_DIR}/infra/nginx"
  "${PROJECT_DIR}/infra/docker-compose.yml"
  "${PROJECT_DIR}/infra/.env"
  "${PROJECT_DIR}/infra/backups"
  "/etc/letsencrypt"
  "/etc/nginx"
)

# ── Docker volumes to snapshot ────────────────────────────────
DOCKER_VOLUMES=(
  "architect-postgres-data:postgres"
  "architect-redis-data:redis"
  "architect-nginx-logs:nginx-logs"
)

# ── Remote storage (S3-compatible: R2, MinIO, etc.) ──────────
# Leave empty to skip. Set via .env or environment.
S3_ENDPOINT="${S3_ENDPOINT:-}"
S3_BUCKET="${S3_BUCKET:-dunaev-backups}"
S3_REGION="${S3_REGION:-auto}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"

# ── Notifications ─────────────────────────────────────────────
# Optional: webhook URL for success/failure notifications
WEBHOOK_URL="${WEBHOOK_URL:-}"

# ── SSH configuration (for remote VPS backups) ────────────────
SSH_KEY="${SSH_KEY:-/root/.ssh/vps_masterhost}"
SSH_HOST="${SSH_HOST:-90.156.129.19}"
SSH_USER="${SSH_USER:-root}"
