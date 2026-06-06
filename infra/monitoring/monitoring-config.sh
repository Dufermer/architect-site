#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Monitoring Configuration — dunaev.dev
# Source this file from monitoring scripts or set via .env
# ═══════════════════════════════════════════════════════════════
#
# Copy to monitoring.env and fill in your credentials:
#   cp monitoring-config.sh monitoring.env
#   vi monitoring.env

set -euo pipefail

# ── Host / Services ───────────────────────────────────────────
HOST_NAME="$(hostname)"
DOMAIN="${DOMAIN:-https://dunaev.dev}"

# Comma-separated health endpoints to check
HEALTH_ENDPOINTS="${HEALTH_ENDPOINTS:-https://dunaev.dev/api/health}"

# Additional HTTP URLs to check (just status 200)
HTTP_CHECKS="${HTTP_CHECKS:-https://dunaev.dev}"

# ── Resource thresholds ──────────────────────────────────────
CPU_WARN="${CPU_WARN:-80}"     # warn if CPU > 80%
CPU_CRIT="${CPU_CRIT:-95}"     # critical if CPU > 95%
RAM_WARN="${RAM_WARN:-80}"     # warn if RAM > 80%
RAM_CRIT="${RAM_CRIT:-95}"     # critical if RAM > 95%
DISK_WARN="${DISK_WARN:-80}"   # warn if disk > 80%
DISK_CRIT="${DISK_CRIT:-92}"   # critical if disk > 92%
LOAD_WARN="${LOAD_WARN:-4.0}"  # warn if load avg > 4.0
LOAD_CRIT="${LOAD_CRIT:-8.0}"  # critical if load avg > 8.0

# ── Alerting (Telegram) ──────────────────────────────────────
# Create a bot: https://t.me/BotFather → /newbot
# Get chat ID: https://api.telegram.org/bot<TOKEN>/getUpdates
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# ── Generic webhook (alternative or additional) ──────────────
WEBHOOK_URL="${WEBHOOK_URL:-}"

# ── Monitoring intervals (seconds) ───────────────────────────
CHECK_INTERVAL="${CHECK_INTERVAL:-300}"  # 5 min between checks
RESOURCE_INTERVAL="${RESOURCE_INTERVAL:-300}"  # 5 min for resources

# ── State tracking ───────────────────────────────────────────
STATE_DIR="${STATE_DIR:-/var/lib/dunaev-monitor}"
PREVIOUS_STATE_FILE="${STATE_DIR}/previous_state.json"

# ── Docker services ──────────────────────────────────────────
DOCKER_COMPOSE_DIR="${DOCKER_COMPOSE_DIR:-/root/dunaev/infra}"
DOCKER_COMPOSE_FILE="${DOCKER_COMPOSE_FILE:-docker-compose.yml}"

# ── Logging ──────────────────────────────────────────────────
LOG_DIR="${LOG_DIR:-/var/log/dunaev}"
MONITOR_LOG="${MONITOR_LOG:-${LOG_DIR}/monitor.log}"
