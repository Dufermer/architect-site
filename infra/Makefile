# ═══════════════════════════════════════════════════════════════
# Makefile — Architect Platform
# Commands for local dev, build, deploy
# ═══════════════════════════════════════════════════════════════

.PHONY: help build up down restart logs ps clean deploy ssh

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ── Docker Compose ─────────────────────────────────────────────
build: ## Build all Docker images
	docker compose -f infra/docker-compose.yml build

up: ## Start core services (backend + frontend)
	docker compose -f infra/docker-compose.yml up -d

up-full: ## Start all services including PostgreSQL, Redis, nginx
	docker compose -f infra/docker-compose.yml --profile full up -d

down: ## Stop all services
	docker compose -f infra/docker-compose.yml down

restart: down up ## Restart core services

logs: ## Follow logs
	docker compose -f infra/docker-compose.yml logs -f

ps: ## List running services
	docker compose -f infra/docker-compose.yml ps

clean: ## Remove all containers, volumes, and built images
	docker compose -f infra/docker-compose.yml down -v --rmi all

# ── Build frontend locally ─────────────────────────────────────
build-frontend: ## Build Astro frontend locally
	cd landing && npm run build

build-backend: ## Build Go backend locally
	cd backend && go build -o architect-api .

# ── Deploy ─────────────────────────────────────────────────────
deploy: ## Deploy via GitHub Actions (push to main triggers CI/CD)
	git push origin main

ssh: ## SSH into VPS
	ssh vps

# ── Security ───────────────────────────────────────────────────
security-check: ## Quick security check
	@echo "=== Listening ports ==="
	@ss -tlnp
	@echo ""
	@echo "=== UFW status ==="
	@sudo ufw status verbose 2>/dev/null || echo "UFW not available"

# ── Backups ─────────────────────────────────────────────────────
backup: ## Run full backup (code + db + config + volumes)
	sudo bash infra/backups/backup.sh all

backup-code: ## Backup only git repositories
	sudo bash infra/backups/backup.sh code

backup-db: ## Backup only databases
	sudo bash infra/backups/backup.sh db

backup-config: ## Backup only configuration files
	sudo bash infra/backups/backup.sh config

backup-volumes: ## Backup only Docker volumes
	sudo bash infra/backups/backup.sh volumes

backup-upload: ## Upload latest backup to S3/R2
	sudo bash infra/backups/backup.sh upload

backup-rotate: ## Remove old backups per retention policy
	sudo bash infra/backups/rotate.sh

backup-list: ## List available backups
	sudo bash infra/backups/restore.sh list

backup-restore: ## Restore from a backup (usage: make backup-restore DATE=20260606 MODE=all)
	sudo bash infra/backups/restore.sh $(DATE) $(MODE)

backup-install-cron: ## Install daily backup cron job
	@echo "Installing cron job..."
	@sudo cp infra/backups/cron/backup-cron /etc/cron.d/dunaev-backup
	@sudo chmod 644 /etc/cron.d/dunaev-backup
	@echo "Cron installed. Backups run daily at 03:00."

# ── Monitoring ───────────────────────────────────────────────────
monitor-health: ## Run health check (HTTP + Docker + SSL)
	sudo bash infra/monitoring/health-check.sh all

monitor-resources: ## Run resource check (CPU, RAM, disk, load)
	sudo bash infra/monitoring/resource-check.sh all

monitor-alert: ## Send a test alert (usage: make monitor-alert MSG="test" SEV=warning)
	sudo bash infra/monitoring/alert.sh "$(MSG)" "$(SEV)"

monitor-install-cron: ## Install monitoring cron jobs
	@echo "Installing monitoring cron job..."
	@sudo mkdir -p /var/log/dunaev /var/lib/dunaev-monitor
	@sudo cp infra/monitoring/monitor-cron /etc/cron.d/dunaev-monitor
	@sudo chmod 644 /etc/cron.d/dunaev-monitor
	@echo "Cron installed. Monitoring runs every 5 minutes."

monitor-install-logrotate: ## Install logrotate config
	@echo "Installing logrotate config..."
	@sudo cp infra/monitoring/logrotate.conf /etc/logrotate.d/dunaev
	@sudo chmod 644 /etc/logrotate.d/dunaev
	@echo "Logrotate installed."

monitor-setup: monitor-install-cron monitor-install-logrotate ## Install all monitoring components
	@echo "Monitoring setup complete."
