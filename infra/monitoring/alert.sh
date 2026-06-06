#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# alert.sh — Send alerts via Telegram webhook
# Part of DUN-105 monitoring stack
# ═══════════════════════════════════════════════════════════════
#
# Usage:
#   ./alert.sh "Service X is down!" "critical"
#   ./alert.sh "CPU > 90%" "warning"
#   ./alert.sh "Disk 85%" "info"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/monitoring-config.sh"

if [[ -f "${CONFIG_FILE}" ]]; then
  source "${CONFIG_FILE}"
fi

# ── Defaults (override via monitoring-config.sh or env) ──────
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
WEBHOOK_URL="${WEBHOOK_URL:-}"

# ── Severity levels ───────────────────────────────────────────
declare -A SEVERITY_ICONS
SEVERITY_ICONS=(
  ["info"]="ℹ️"
  ["warning"]="⚠️"
  ["critical"]="🚨"
  ["recovery"]="✅"
)

declare -A SEVERITY_COLORS
SEVERITY_COLORS=(
  ["info"]="#3498db"
  ["warning"]="#f39c12"
  ["critical"]="#e74c3c"
  ["recovery"]="#2ecc71"
)

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# ── Format message ────────────────────────────────────────────
format_telegram() {
  local severity="${2:-info}"
  local icon="${SEVERITY_ICONS[$severity]:-ℹ️}"
  local host
  host="$(hostname)"

  cat <<EOF
${icon} <b>[${host}]</b> ${severity^^}

$1

<code>$(date '+%Y-%m-%d %H:%M:%S %Z')</code>
EOF
}

# ── Send via Telegram Bot API ─────────────────────────────────
send_telegram() {
  local message="$1"

  if [[ -z "${TELEGRAM_BOT_TOKEN}" || -z "${TELEGRAM_CHAT_ID}" ]]; then
    log "Telegram not configured — skipping (set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID)"
    return 1
  fi

  local response
  response="$(curl -fsS -m 10 -X POST \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "$(cat <<JSON
{
  "chat_id": "${TELEGRAM_CHAT_ID}",
  "text": $(echo "${message}" | jq -Rs '.'),
  "parse_mode": "HTML",
  "disable_web_page_preview": true
}
JSON
    )" 2>&1)" || {
    log "Telegram send failed: ${response}"
    return 1
  }

  log "Alert sent via Telegram"
}

# ── Send via generic webhook ──────────────────────────────────
send_webhook() {
  local message="$1"
  local severity="${2:-info}"

  if [[ -z "${WEBHOOK_URL}" ]]; then
    return 0  # not configured — not an error
  fi

  curl -fsS -m 10 -X POST "${WEBHOOK_URL}" \
    -H "Content-Type: application/json" \
    -d "$(cat <<JSON
{
  "text": "${message}",
  "severity": "${severity}",
  "host": "$(hostname)",
  "timestamp": "$(date -Iseconds)"
}
JSON
    )" >/dev/null 2>&1 && log "Alert sent via webhook" || log "Webhook send failed"
}

# ── Main ──────────────────────────────────────────────────────
main() {
  local message="${1:-No message}"
  local severity="${2:-info}"

  local formatted
  formatted="$(format_telegram "${message}" "${severity}")"

  send_telegram "${formatted}"
  send_webhook "${message}" "${severity}"
}

main "$@"
