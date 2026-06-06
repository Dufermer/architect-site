#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Deploy Script — Architect Platform
# Pushes code to GitHub → triggers CI/CD
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }

# Check for uncommitted changes
if ! git diff --quiet HEAD 2>/dev/null; then
    echo "Uncommitted changes detected. Commit first:"
    echo "  git add -A && git commit -m \"your message\""
    exit 1
fi

echo "============================================"
echo "  Deploying Architect Platform"
echo "  $(date -u)"
echo "============================================"

# Push landing page
log "Pushing landing page..."
cd landing
git push origin main
cd ..

log "Deploy triggered! Check:"
echo "  https://github.com/Dufermer/architect-site/actions"
echo "  https://dunaev.dev (after DNS + deploy complete)"
