#!/usr/bin/env bash
# run-local-failover.sh — lance le mqtt5-worker en local (WSL Debian) en
# failover actif/actif du container Cloudflare Containers.
#
# Le claim atomique des device_commands (UPDATE ... WHERE status='pending')
# garantit qu'une commande n'est traitée qu'une seule fois, quel que soit le
# worker qui la remporte : Cloudflare (quand réveillé) ou local (toujours on).
# Aucun keep-alive Cloudflare n'est donc nécessaire.
#
# Prérequis :
#   - docker.io installé et dockerd lancé (WSL Debian)
#   - cloudflared installé + authentifié (`cloudflared tunnel login`)
#   - variables dans .env (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY,
#     FLESPI_MQTT_WORKER_TOKEN, FLESPI_MQTT_HOST, FLESPI_MQTT_TCP_PORT)
#
# Usage :
#   ./scripts/run-local-failover.sh                # build + run du container
#   TUNNEL_NAME=aricie-mqtt ./scripts/run-local-failover.sh  # + tunnel cloudflared

set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE=aricie/mqtt5-worker:local
CONTAINER=mqtt5-worker-local
TUNNEL_NAME=${TUNNEL_NAME:-aricie-mqtt-worker}
TUNNEL_PORT=${TUNNEL_PORT:-18080}

[ -f .env ] || { echo "ERREUR: .env manquant dans workers/mqtt5-worker/"; exit 1; }

echo "==> Build de l'image locale"
docker build -t "$IMAGE" .

echo "==> (Re)démarrage du container (restart unless-stopped)"
docker rm -f "$CONTAINER" 2>/dev/null || true
docker run -d \
  --name "$CONTAINER" \
  --restart unless-stopped \
  --env-file .env \
  -p "127.0.0.1:${TUNNEL_PORT}:8080" \
  "$IMAGE"

echo "==> Health check local"
sleep 3
curl -sf "http://127.0.0.1:${TUNNEL_PORT}/health" | head -c 300 || {
  echo "HEALTH FAILED — logs:"
  docker logs --tail 30 "$CONTAINER"
  exit 1
}
echo

if command -v cloudflared >/dev/null 2>&1; then
  echo "==> Tunnel cloudflared : expose http://localhost:${TUNNEL_PORT} en prod"
  if ! cloudflared tunnel list 2>/dev/null | grep -q "$TUNNEL_NAME"; then
    echo "Création du tunnel nommé '$TUNNEL_NAME'..."
    cloudflared tunnel create "$TUNNEL_NAME"
  fi
  TUNNEL_ID=$(cloudflared tunnel list 2>/dev/null | awk -v n="$TUNNEL_NAME" '$2==n {print $1; exit}')
  cat > /tmp/cf-tunnel-"$TUNNEL_NAME".yml <<EOF
tunnel: $TUNNEL_ID
credentials-file: $HOME/.cloudflared/$TUNNEL_ID.json
ingress:
  - hostname: mqtt-worker.benji-aka-dev.site
    service: http://127.0.0.1:${TUNNEL_PORT}
  - service: http_status:404
EOF
  echo "Route DNS à créer (une fois) :"
  echo "  cloudflared tunnel route dns $TUNNEL_NAME mqtt-worker.benji-aka-dev.site"
  echo "Lancement :"
  echo "  cloudflared tunnel --config /tmp/cf-tunnel-$TUNNEL_NAME.yml run $TUNNEL_NAME"
else
  echo "cloudflared absent : container local opérationnel sur 127.0.0.1:${TUNNEL_PORT} (sans tunnel)."
fi

echo "==> Suivi des logs : docker logs -f $CONTAINER"
