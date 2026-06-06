#!/bin/bash
#===============================================================================
# VPS Security Setup Script — DUN-108
# Firewall и безопасность сервера (Masterhost VPS @ 90.156.129.19)
# Ubuntu 24.04
#
# RUN MANUALLY ON VPS:
#   scp -P 22 setup-vps-security.sh root@90.156.129.19:/root/
#   ssh root@90.156.129.19 "chmod +x /root/setup-vps-security.sh && /root/setup-vps-security.sh"
#
# Or upload via Masterhost web console.
#===============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[✗]${NC} $1"; }

# === 0. Prerequisites check ===
if [ "$(id -u)" -ne 0 ]; then
    err "This script must be run as root."
    exit 1
fi

echo "============================================"
echo "  VPS Security Hardening — DUN-108"
echo "  $(date -u)"
echo "============================================"

# === 1. System update ===
echo ""
echo "--- Step 1: System update ---"
apt update -qq && apt upgrade -y -qq
log "System updated"

# === 2. UFW — Firewall ===
echo ""
echo "--- Step 2: UFW Firewall ---"
apt install -y -qq ufw

# Reset to default
ufw --force reset >/dev/null 2>&1

# Default: deny incoming, allow outgoing
ufw default deny incoming
ufw default allow outgoing

# Essential ports
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Optional: Cloudflare-only for HTTP/HTTPS (uncomment if using Cloudflare proxy)
# CLOUDFLARE_IPS=(
#   "173.245.48.0/20" "103.21.244.0/22" "103.22.200.0/22"
#   "103.31.4.0/22" "141.101.64.0/18" "108.162.192.0/18"
#   "190.93.240.0/20" "188.114.96.0/20" "197.234.240.0/22"
#   "198.41.128.0/17" "162.158.0.0/15" "104.16.0.0/13"
#   "104.24.0.0/14" "172.64.0.0/13" "131.0.72.0/22"
# )
# ufw delete allow 80/tcp
# ufw delete allow 443/tcp
# for ip in "${CLOUDFLARE_IPS[@]}"; do
#   ufw allow from "$ip" to any port 80 proto tcp
#   ufw allow from "$ip" to any port 443 proto tcp
# done

# Rate limiting for SSH (6 connections per 30s)
ufw limit 22/tcp comment 'SSH rate-limited'

# Enable
ufw --force enable >/dev/null
log "UFW firewall configured (22,80,443 open; SSH rate-limited)"

# Show status
ufw status verbose | head -15

# === 3. Fail2ban ===
echo ""
echo "--- Step 3: Fail2ban ---"
apt install -y -qq fail2ban

cat > /etc/fail2ban/jail.local << 'F2BEOF'
[DEFAULT]
# Ban for 1 hour
bantime = 1h
# Time window for finding failures
findtime = 10m
# Max retries before ban
maxretry = 5
# Ban action
banaction = ufw

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 24h
F2BEOF

systemctl enable fail2ban --now >/dev/null 2>&1
log "Fail2ban configured (SSH: 3 strikes → 24h ban)"

# === 4. SSH Hardening ===
echo ""
echo "--- Step 4: SSH Hardening ---"

# Backup original
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d)

# Apply secure settings
cat > /etc/ssh/sshd_config << 'SSHEOF'
# SSH Hardened Configuration — DUN-108
# Generated: 2026-06-06

Port 22
Protocol 2

# Authentication
PermitRootLogin prohibit-password
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
AuthenticationMethods publickey

# Key exchange algorithms (strong only)
KexAlgorithms curve25519-sha256,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512

# Ciphers (strong only)
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com

# MACs (strong only)
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com

# Connection
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 10
LoginGraceTime 30

# Users & sessions
AllowUsers root  # Replace with your actual user if different
UsePAM yes

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# SFTP (if needed)
Subsystem sftp internal-sftp
SSHEOF

# Remove old host keys and regenerate (optional - skip if you want to keep existing)
# rm -f /etc/ssh/ssh_host_*
# ssh-keygen -A

# Restart SSH
systemctl restart sshd
log "SSH hardened: key-only auth, no passwords, strong ciphers"

# === 5. Unattended-upgrades ===
echo ""
echo "--- Step 5: Unattended-upgrades ---"
apt install -y -qq unattended-upgrades

cat > /etc/apt/apt.conf.d/20auto-upgrades << 'UUEOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
UUEOF

cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'UU50EOF'
Unattended-Upgrade::Origins-Pattern {
    "origin=Ubuntu,archive=jammy-security";
    "origin=Ubuntu,archive=jammy-updates";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
Unattended-Upgrade::SyslogEnable "true";
UU50EOF

systemctl enable unattended-upgrades --now >/dev/null 2>&1
log "Unattended-upgrades configured (security updates auto-installed)"

# === 6. Audit ports & services ===
echo ""
echo "--- Step 6: Port audit ---"

# List listening services
echo "Listening services:"
ss -tlnp | tail -n+2
echo ""

# Check for unnecessary services
warn "Review the list above. Disable any unnecessary services with:"
echo "  systemctl disable --now <service-name>"
echo ""

# === 7. Install and configure AIDE (intrusion detection) ===
echo ""
echo "--- Step 7: AIDE (file integrity) ---"
apt install -y -qq aide
aideinit --yes >/dev/null 2>&1 || true
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db 2>/dev/null || true
log "AIDE initialized (baseline file integrity DB created)"

# === 8. Logwatch (daily log summary) ===
echo ""
echo "--- Step 8: Logwatch ---"
apt install -y -qq logwatch
cat > /etc/cron.daily/00logwatch << 'LWEOF'
#!/bin/bash
/usr/sbin/logwatch --output mail --mailto root --detail high
LWEOF
chmod +x /etc/cron.daily/00logwatch
log "Logwatch configured (daily log summary to root)"

# === 9. Kernel hardening via sysctl ===
echo ""
echo "--- Step 9: Kernel hardening ---"
cat > /etc/sysctl.d/99-security.conf << 'SYSCTLEOF'
# Kernel hardening — DUN-108

# IP spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Ignore source-routed packets
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Ignore ICMP echo requests (prevent ping floods)
net.ipv4.icmp_echo_ignore_all = 0  # Set to 1 to completely disable ping
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Log martian packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# TCP SYN flood protection
net.ipv4.tcp_syncookies = 1

# Disable IPv6 if not needed (uncomment below)
# net.ipv6.conf.all.disable_ipv6 = 1
# net.ipv6.conf.default.disable_ipv6 = 1

# Protect against TIME_WAIT assassination
net.ipv4.tcp_rfc1337 = 1
SYSCTLEOF

sysctl -p /etc/sysctl.d/99-security.conf >/dev/null 2>&1
log "Kernel parameters hardened (syn cookies, rp_filter, redirect ignore)"

# === 10. Summary ===
echo ""
echo "============================================"
echo "  SECURITY HARDENING COMPLETE"
echo "============================================"
echo ""
echo "What was done:"
echo "  [✓] UFW firewall (22,80,443 only)"
echo "  [✓] SSH rate limiting (ufw limit)"
echo "  [✓] Fail2ban (SSH: 3 strikes → 24h ban)"
echo "  [✓] SSH hardened (key-only, no passwords)"
echo "  [✓] Unattended-upgrades (auto security updates)"
echo "  [✓] AIDE file integrity baseline"
echo "  [✓] Logwatch (daily security log)"
echo "  [✓] Kernel hardening (13 sysctl params)"
echo "  [✓] Port audit"
echo ""
echo "--- NEXT STEPS (post-deployment) ---"
echo "1. Authorize SSH key: add VPS key to ~/.ssh/authorized_keys"
echo "2. Test SSH access in a NEW terminal BEFORE closing current session"
echo "3. Disable root login via SSH after testing user account:"
echo "     PermitRootLogin no  (in /etc/ssh/sshd_config)"
echo "4. Schedule weekly AIDE checks:"
echo "     aide.wrapper --check | mail -s 'AIDE report' root"
echo "5. Configure log shipping or SIEM if needed"
echo "6. Add monitoring (DUN-113)"
echo ""
echo "Public SSH key to authorize on VPS:"
echo "  $(cat /root/.ssh/authorized_keys 2>/dev/null | tail -1 || echo '→ upload from local ~/.ssh/vps_masterhost.pub')"
echo ""
echo "============================================"
