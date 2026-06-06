#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# health-check.sh — Uptime monitoring for dunaev.dev
# Part of DUN-105 monitoring stack
#
# Checks:
#   - HTTP health endpoints (200 + response time)
#   - Docker container health
#   - SSL certificate expiry
# ═══════════════════════════════════════════════════════════════
#
# Usage:
#   ./health-check.sh                     # full check
#   ./health-check.sh http                # HTTP endpoints only
#   ./health-check.sh docker              # Docker containers only
#   ./health-check.sh ssl                 # SSL expiry only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/monitoring-config.sh"

ALERT_SCRIPT="${SCRIPT_DIR}/alert.sh"
STATE_FILE="${PREVIOUS_STATE_FILE:-/var/lib/dunaev-monitor/health_state.json}"

mkdir -p "$(dirname "${STATE_FILE}")" "$(dirname "${MONITOR_LOG}")" 2>/dev/null || true

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "${MONITOR_LOG}"; }

# ── Load/save previous state (for recovery detection) ─────────
load_state() {
  if [[ -f "${STATE_FILE}" ]]; then
    previous_healthy=true
  else
    previous_healthy=false
  fi
}

save_state() {
  local status="$1"
  echo '{"healthy":'"${status}"',"timestamp":"'"$(date -Iseconds)"'"}' > "${STATE_FILE}"
}

alert() {
  local message="$1"
  local severity="${2:-info}"
  bash "${ALERT_SCRIPT}" "${message}" "${severity}" || true
}

# ── 1. HTTP Health Check ──────────────────────────────────────
check_http() {
  log "=== HTTP health checks ==="
  local all_ok=true

  IFS=',' read -ra endpoints <<< "${HEALTH_ENDPOINTS}"
  for endpoint in "${endpoints[@]}"; do
    endpoint="$(echo "${endpoint}" | xargs)"
    [[ -z "${endpoint}" ]] && continue

    local start_time
    start_time="$(date +%s%N)"
    local http_code
    http_code="$(curl -o /dev/null -s -w '%{http_code}' --max-time 10 "${endpoint}" 2>/dev/null || echo "000")"
    local end_time
    end_time="$(date +%s%N)"
    local response_ms=$(( (end_time - start_time) / 1000000 ))

    if [[ "${http_code}" == "200" || "${http_code}" == "204" ]]; then
      log "OK   ${endpoint} → ${http_code} (${response_ms}ms)"
    else
      log "DOWN ${endpoint} → ${http_code} (${response_ms}ms)"
      alert "❌ Health check FAILED: ${endpoint}\nHTTP ${http_code} — response ${response_ms}ms" "critical"
      all_ok=false
    fi
  done

  # Additional HTTP URL checks
  IFS=',' read -ra urls <<< "${HTTP_CHECKS}"
  for url in "${urls[@]}"; do
    url="$(echo "${url}" | xargs)"
    [[ -z "${url}" ]] && continue

    local http_code
    http_code="$(curl -o /dev/null -s -w '%{http_code}' --max-time 10 --location "${url}" 2>/dev/null || echo "000")"

    if [[ "${http_code}" == "200" || "${http_code}" == "204" || "${http_code}" == "301" || "${http_code}" == "302" ]]; then
      log "OK   ${url} → ${http_code}"
    else
      log "DOWN ${url} → ${http_code}"
      alert "❌ Site check FAILED: ${url}\nHTTP ${http_code}" "critical"
      all_ok=false
    fi
  done

  ${all_ok}
}

# ── 2. Docker Container Health ────────────────────────────────
check_docker() {
  log "=== Docker container health ==="
  local all_ok=true

  if ! command -v docker &>/dev/null; then
    log "Docker not available — skipping"
    return 0
  fi

  local containers
  containers="$(docker ps --format '{{.Names}} {{.Status}}' 2>/dev/null)" || {
    log "Cannot list Docker containers — daemon may be down"
    alert "❌ Docker daemon unreachable" "critical"
    return 1
  }

  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    local name="${line%% *}"
    local status="${line#* }"

    if echo "${status}" | grep -qiE "(unhealthy|restarting|exited)"; then
      log "UNHEALTHY ${name} → ${status}"
      alert "❌ Container unhealthy: ${name}\nStatus: ${status}" "critical"
      all_ok=false
    elif echo "${status}" | grep -qi "up"; then
      log "OK   ${name} → ${status}"
    else
      log "???  ${name} → ${status}"
      all_ok=false
    fi
  done <<< "${containers}"

  ${all_ok}
}

# ── 3. SSL Certificate Check ──────────────────────────────────
check_ssl() {
  log "=== SSL certificate check ==="
  local all_ok=true
  local domain
  domain="$(echo "${DOMAIN}" | sed 's|https\?://||' | sed 's|/.*||')"

  if [[ -z "${domain}" ]]; then
    log "No domain configured — skipping SSL check"
    return 0
  fi

  local expiry_date
  local days_left

  expiry_date="$(echo | openssl s_client -servername "${domain}" -connect "${domain}:443" 2>/dev/null \
    | openssl x509 -noout -enddate 2>/dev/null \
    | sed 's/notAfter=//')" || {
    log "Cannot check SSL for ${domain}"
    return 1
  }

  if [[ -n "${expiry_date}" ]]; then
    days_left=$(( ($(date -d "${expiry_date}" +%s) - $(date +%s)) / 86400 ))

    if [[ ${days_left} -le 3 ]]; then
      log "CRITICAL SSL: ${domain} expires in ${days_left} days"
      alert "🚨 SSL certificate expires in ${days_left} days!\nDomain: ${domain}\nRenew immediately!" "critical"
      all_ok=false
    elif [[ ${days_left} -le 14 ]]; then
      log "WARN  SSL: ${domain} expires in ${days_left} days"
      alert "⚠️ SSL certificate expires in ${days_left} days\nDomain: ${domain}" "warning"
    else
      log "OK    SSL: ${domain} expires in ${days_left} days"
    fi
  fi

  ${all_ok}
}

# ── Main ──────────────────────────────────────────────────────
main() {
  local mode="${1:-all}"
  local exit_code=0

  load_state

  case "${mode}" in
    http)
      check_http || exit_code=1
      ;;
    docker)
      check_docker || exit_code=1
      ;;
    ssl)
      check_ssl || exit_code=1
      ;;
    all|"")
      check_http   || exit_code=1
      check_docker || exit_code=1
      check_ssl    || exit_code=1
      ;;
    *)
      echo "Usage: $0 {http|docker|ssl|all}"
      exit 1
      ;;
  esac

  if [[ ${exit_code} -eq 0 ]]; then
    save_state "true"
    # Recovery alert if was previously down
    if [[ "${previous_healthy}" == "false" ]]; then
      alert "✅ All health checks PASSED — services recovered" "recovery"
    fi
  else
    save_state "false"
  fi

  return ${exit_code}
}

main "$@"
