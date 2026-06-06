#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# resource-check.sh — System resource monitoring
# Part of DUN-105 monitoring stack
#
# Checks:
#   - CPU usage (%)
#   - RAM usage (%)
#   - Disk usage (%) per mount
#   - Load average
#   - Network I/O (optional)
# ═══════════════════════════════════════════════════════════════
#
# Usage:
#   ./resource-check.sh                # full check
#   ./resource-check.sh cpu            # CPU only
#   ./resource-check.sh mem            # memory only
#   ./resource-check.sh disk           # disk only
#   ./resource-check.sh load           # load average only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/monitoring-config.sh"

ALERT_SCRIPT="${SCRIPT_DIR}/alert.sh"
STATE_DIR="${STATE_DIR:-/var/lib/dunaev-monitor}"
mkdir -p "$(dirname "${MONITOR_LOG}")" "${STATE_DIR}" 2>/dev/null || true

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "${MONITOR_LOG}"; }

alert() {
  local message="$1"
  local severity="${2:-info}"
  bash "${ALERT_SCRIPT}" "${message}" "${severity}" || true
}

# ── Global exit code ──────────────────────────────────────────
EXIT_CODE=0

# ── 1. CPU Check ──────────────────────────────────────────────
check_cpu() {
  log "=== CPU usage ==="
  local cpu_idle
  cpu_idle="$(top -bn1 2>/dev/null | grep 'Cpu(s)' | awk '{print $8}' | sed 's/\..*//' || echo "100")"
  local cpu_used=$(( 100 - cpu_idle ))

  log "CPU: ${cpu_used}% used"

  if [[ ${cpu_used} -ge ${CPU_CRIT} ]]; then
    alert "🚨 CPU usage CRITICAL: ${cpu_used}% (threshold: ${CPU_CRIT}%)" "critical"
    EXIT_CODE=1
  elif [[ ${cpu_used} -ge ${CPU_WARN} ]]; then
    alert "⚠️ CPU usage WARNING: ${cpu_used}% (threshold: ${CPU_WARN}%)" "warning"
  fi

  # Top processes by CPU
  if [[ ${cpu_used} -ge ${CPU_WARN} ]]; then
    local top_cpu
    top_cpu="$(ps aux --sort=-%cpu 2>/dev/null | head -4 | tail -n +2 | awk '{printf "  %s %.1f%% %s\\n", $11, $3, $2}')"
    log "Top CPU processes:"
    log "${top_cpu}"
  fi
}

# ── 2. Memory Check ───────────────────────────────────────────
check_mem() {
  log "=== Memory usage ==="

  if command -v free &>/dev/null; then
    local mem_info
    mem_info="$(free -m)"
    local total
    total="$(echo "${mem_info}" | awk '/^Mem:/{print $2}')"
    local used
    used="$(echo "${mem_info}" | awk '/^Mem:/{print $3}')"
    local pct=$(( used * 100 / (total > 0 ? total : 1) ))

    log "RAM: ${used}MB / ${total}MB (${pct}%)"

    if [[ ${pct} -ge ${RAM_CRIT} ]]; then
      alert "🚨 RAM usage CRITICAL: ${pct}% (threshold: ${RAM_CRIT}%)" "critical"
      EXIT_CODE=1
    elif [[ ${pct} -ge ${RAM_WARN} ]]; then
      alert "⚠️ RAM usage WARNING: ${pct}% (threshold: ${RAM_WARN}%)" "warning"
    fi
  else
    log "free not available — skipping memory check"
  fi

  # Swap usage
  if command -v free &>/dev/null; then
    local swap_total
    swap_total="$(free -m | awk '/^Swap:/{print $2}')"
    local swap_used
    swap_used="$(free -m | awk '/^Swap:/{print $3}')"
    if [[ ${swap_total} -gt 0 ]]; then
      local swap_pct=$(( swap_used * 100 / swap_total ))
      log "Swap: ${swap_used}MB / ${swap_total}MB (${swap_pct}%)"
      if [[ ${swap_pct} -ge 50 ]]; then
        alert "⚠️ Swap usage WARNING: ${swap_pct}% (${swap_used}MB / ${swap_total}MB)" "warning"
      fi
    fi
  fi
}

# ── 3. Disk Check ─────────────────────────────────────────────
check_disk() {
  log "=== Disk usage ==="
  local warn_found=false

  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    local mount
    mount="$(echo "${line}" | awk '{print $NF}')"
    local pct
    pct="$(echo "${line}" | awk '{print $5}' | sed 's/%//')"
    local used
    used="$(echo "${line}" | awk '{print $3}')"
    local total
    total="$(echo "${line}" | awk '{print $2}')"

    # Skip virtual/overlay filesystems
    case "${mount}" in
      /dev|/proc|/sys|/run|/var/lib/docker/*|/var/lib/containerd/*|overlay*)
        continue ;;
    esac

    log "Disk ${mount}: ${pct}% used (${used}/${total})"

    if [[ ${pct} -ge ${DISK_CRIT} ]]; then
      alert "🚨 Disk CRITICAL: ${mount} at ${pct}% (threshold: ${DISK_CRIT}%)" "critical"
      EXIT_CODE=1
      warn_found=true
    elif [[ ${pct} -ge ${DISK_WARN} ]]; then
      alert "⚠️ Disk WARNING: ${mount} at ${pct}% (threshold: ${DISK_WARN}%)" "warning"
      warn_found=true
    fi
  done < <(df -h 2>/dev/null | tail -n +2)

  if [[ "${warn_found}" == "false" ]]; then
    log "All disks OK"
  fi

  # Inode usage
  log "=== Inode usage ==="
  df -i 2>/dev/null | tail -n +2 | head -5 | while IFS= read -r line; do
    local mount
    mount="$(echo "${line}" | awk '{print $NF}')"
    local pct
    pct="$(echo "${line}" | awk '{print $5}' | sed 's/%//')"
    case "${mount}" in
      /dev|/proc|/sys|/run|/var/lib/docker/*) continue ;;
    esac
    [[ "${pct}" =~ ^[0-9]+$ ]] || continue
    if [[ ${pct} -ge 90 ]]; then
      alert "⚠️ Inode usage WARNING: ${mount} at ${pct}%" "warning"
    fi
  done
}

# ── 4. Load Average Check ────────────────────────────────────
check_load() {
  log "=== Load average ==="
  local load_1
  load_1="$(cat /proc/loadavg 2>/dev/null | awk '{print $1}' || echo "0")"

  log "Load 1min: ${load_1}"

  local load_compare
  load_compare="$(echo "${load_1} > ${LOAD_CRIT}" | bc 2>/dev/null || echo "0")"
  if [[ "${load_compare}" == "1" ]]; then
    alert "🚨 Load CRITICAL: ${load_1} (threshold: ${LOAD_CRIT})" "critical"
    EXIT_CODE=1
  else
    load_compare="$(echo "${load_1} > ${LOAD_WARN}" | bc 2>/dev/null || echo "0")"
    if [[ "${load_compare}" == "1" ]]; then
      alert "⚠️ Load WARNING: ${load_1} (threshold: ${LOAD_WARN})" "warning"
    fi
  fi
}

# ── 5. Network Check (optional) ───────────────────────────────
check_network() {
  log "=== Network interfaces ==="
  if command -v ip &>/dev/null; then
    ip -br addr 2>/dev/null | grep -v '^lo ' | while IFS= read -r line; do
      local iface
      iface="$(echo "${line}" | awk '{print $1}')"
      local addr
      addr="$(echo "${line}" | awk '{print $3}')"
      log "IF  ${iface}: ${addr:-no IP}"
    done
  fi

  # Check if internet is reachable
  if ping -c 1 -W 5 8.8.8.8 &>/dev/null; then
    log "Internet: OK"
  else
    log "Internet: UNREACHABLE"
    alert "🌐 Internet connectivity lost" "critical"
    EXIT_CODE=1
  fi
}

# ── Main ──────────────────────────────────────────────────────
main() {
  local mode="${1:-all}"

  log "═══════════════════════════════════════════"
  log "Resource Check — $(date)"
  log "═══════════════════════════════════════════"

  case "${mode}" in
    cpu)     check_cpu ;;
    mem)     check_mem ;;
    disk)    check_disk ;;
    load)    check_load ;;
    network) check_network ;;
    all|"")
      check_cpu
      check_mem
      check_disk
      check_load
      check_network
      ;;
    *)
      echo "Usage: $0 {cpu|mem|disk|load|network|all}"
      exit 1
      ;;
  esac

  log "Resource check complete (exit=${EXIT_CODE})"
  return ${EXIT_CODE}
}

main "$@"
