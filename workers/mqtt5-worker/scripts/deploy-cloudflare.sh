#!/usr/bin/env bash
# deploy-cloudflare.sh — build, push et deploy du mqtt5-worker vers Cloudflare Containers.
#
# Prérequis :
#   - wrangler authentifié (`wrangler login` ou config ~/.config/.wrangler)
#   - Docker disponible (local ou WSL Debian)
#   - Secrets posés : wrangler secret put SUPABASE_URL
#                      wrangler secret put SUPABASE_SERVICE_ROLE_KEY
#                      wrangler secret put FLESPI_MQTT_WORKER_TOKEN
#
# Usage :
#   ./scripts/deploy-cloudflare.sh            # build + push + deploy complet
#   SKIP_BUILD=1 ./scripts/deploy-cloudflare.sh   # deploy seul (réutilise l'image)

set -euo pipefail
cd "$(dirname "$0")/.."

if [ "${SKIP_BUILD:-0}" != "1" ]; then
  echo "==> Build de l'image (docker via wrangler)"
  wrangler containers build . -t aricie-mqtt5-worker:latest
  echo "==> Push vers le registre Cloudflare"
  wrangler containers push aricie-mqtt5-worker:latest
fi

echo "==> Deploy du Worker + Container"
wrangler deploy

echo "==> État des containers"
wrangler containers list

echo "Déployé. Santé : curl https://aricie-mqtt5-worker.<subdomain>.workers.dev/health"
