# Security Playbook — DUN-108
## Firewall и безопасность сервера (Masterhost VPS)
**Server:** 90.156.129.19 | **OS:** Ubuntu 24.04 | **Host:** Masterhost

---

## Current Status: 🔴 Blocked — No SSH Access to VPS

The VPS (90.156.129.19) rejects SSH connections because **no SSH key is authorized** on the server from this machine. The Masterhost VPS has password auth potentially enabled, but the password is not stored in credentials.

### Blockers:
- ❌ No SSH key authorized on VPS for agent workstation
- ❌ VPS root password unknown (not in credentials store)
- ❌ Cannot apply any security measures remotely

---

## How to Unblock

### Option A: Install SSH key via Masterhost web console
1. Login to Masterhost web panel
2. Find VPS console / VNC access
3. Run:
```bash
mkdir -p ~/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDbsnYzKqbMCZuToV86l0l41T8niTcP9u4ZJ2DX2OlyV devops-agent-vps-2026-06-06" >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```
4. Test from local: `ssh vps` (after adding config)

### Option B: Password-based login (if Masterhost sent credentials)
```bash
ssh-copy-id -i ~/.ssh/vps_masterhost root@90.156.129.19
```

### Option C: Generate key on VPS and copy back
Use Masterhost VNC, generate keypair there, copy public key back.

---

## What setup-vps-security.sh Does (when run on VPS)

| # | Component | Action |
|---|-----------|--------|
| 1 | System update | `apt update && apt upgrade` |
| 2 | UFW Firewall | Deny all inbound, allow 22/80/443, rate-limit SSH |
| 3 | Fail2ban | 3 SSH failures → 24h ban via UFW |
| 4 | SSH hardening | Key-only auth, strong ciphers (chacha20/aes256-gcm), disable passwords |
| 5 | Unattended-upgrades | Auto-install security updates nightly |
| 6 | Port audit | List all listening services |
| 7 | AIDE | File integrity baseline for intrusion detection |
| 8 | Logwatch | Daily email summary of system activity |
| 9 | Kernel hardening | syn cookies, rp_filter, ignore redirects, 13 sysctl params |

---

## Post-Script Steps

After successful SSH connection and running the script:

1. **Test SSH in a second terminal** — never close the active session until verified
2. **Disable root password login**: edit `/etc/ssh/sshd_config` → `PermitRootLogin no`
3. **Add cloudflare-only firewall rules** (uncomment in script or run separately):
   ```bash
   curl -s https://www.cloudflare.com/ips-v4 | xargs -I% ufw allow from % to any port 80,443 proto tcp
   curl -s https://www.cloudflare.com/ips-v6 | xargs -I% ufw allow from % to any port 80,443 proto tcp
   ufw delete allow 80/tcp
   ufw delete allow 443/tcp
   ```
4. **Schedule AIDE checks** via cron:
   ```bash
   echo "0 4 * * 0 root aide.wrapper --check | mail -s 'AIDE weekly report' root" > /etc/cron.d/aide-check
   ```
5. **Save credentials**:
   ```bash
   # Add to ~/.hermes/imported/credentials.yaml
   vps_masterhost:
     ssh_key_path: ~/.ssh/vps_masterhost
     authorized: true
     last_test: 2026-06-06
   ```

---

## Verification Commands

Run these **after** setup to verify:

```bash
# Firewall status
ufw status verbose

# Fail2ban status
fail2ban-client status sshd

# SSH config
sshd -T | grep -E '(permitrootlogin|passwordauthentication|pubkeyauthentication)'

# Listening ports
ss -tlnp

# Unattended upgrades
systemctl status unattended-upgrades
grep -c "Unattended-Upgrade" /var/log/unattended-upgrades/unattended-upgrades.log

# Kernel hardening
sysctl net.ipv4.tcp_syncookies net.ipv4.conf.all.rp_filter
```

---

## Files Created

| File | Path |
|------|------|
| Setup script | `security/setup-vps-security.sh` |
| SSH key (local) | `~/.ssh/vps_masterhost` |
| SSH pub key | `~/.ssh/vps_masterhost.pub` |
| This playbook | `security/SECURITY-PLAYBOOK.md` |
