#!/usr/bin/env bash
# aricie — démarre le pont OpenCode (modèles free) + tunnel public.
#
#   bash workers/opencode-bridge/start.sh              # pont + tunnel + secret Supabase
#   bash workers/opencode-bridge/start.sh --no-tunnel  # pont seul (tests locaux)
#   bash workers/opencode-bridge/start.sh --no-secret  # tunnel mais sans toucher aux secrets
#
# Prérequis : `opencode` dans le PATH (le pont le lance lui-même si besoin),
# `cloudflared` pour le tunnel, `supabase` CLI pour pousser le secret.
#
# Ctrl+C arrête le pont et le tunnel.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
LOG_DIR="$HERE/.logs"
mkdir -p "$LOG_DIR"

BRIDGE_PORT="${BRIDGE_PORT:-4097}"
OPENCODE_URL="${OPENCODE_URL:-http://127.0.0.1:4096}"
OPENCODE_MODEL="${OPENCODE_MODEL:-deepseek-v4.1-flash-free}"
CLOUDFLARED="${CLOUDFLARED:-cloudflared}"
USE_TUNNEL=1
PUSH_SECRET=1

for arg in "$@"; do
  case "$arg" in
    --no-tunnel) USE_TUNNEL=0 ;;
    --no-secret) PUSH_SECRET=0 ;;
    *) echo "argument inconnu: $arg" >&2; exit 2 ;;
  esac
done

cleanup() {
  echo ""
  echo "==> arrêt"
  [[ -n "${TUNNEL_PID:-}" ]] && kill "$TUNNEL_PID" 2>/dev/null || true
  [[ -n "${BRIDGE_PID:-}" ]] && kill "$BRIDGE_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# --- 1. Tunnel -------------------------------------------------------------
PUBLIC_URL=""
if [[ "$USE_TUNNEL" == "1" ]]; then
  if ! command -v "$CLOUDFLARED" >/dev/null 2>&1; then
    echo "cloudflared introuvable — relance avec --no-tunnel, ou installe-le." >&2
    exit 1
  fi
  echo "==> tunnel cloudflared → http://127.0.0.1:${BRIDGE_PORT}"
  "$CLOUDFLARED" tunnel --no-autoupdate --url "http://127.0.0.1:${BRIDGE_PORT}" \
    > "$LOG_DIR/cloudflared.log" 2>&1 &
  TUNNEL_PID=$!

  for _ in $(seq 1 40); do
    PUBLIC_URL=$(grep -Eo 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG_DIR/cloudflared.log" | head -1 || true)
    [[ -n "$PUBLIC_URL" ]] && break
    sleep 0.5
  done

  if [[ -z "$PUBLIC_URL" ]]; then
    echo "tunnel : URL publique introuvable (voir $LOG_DIR/cloudflared.log)" >&2
  else
    echo "==> URL publique : $PUBLIC_URL"
  fi
fi

# --- 2. Secret Supabase ----------------------------------------------------
BRIDGE_TOKEN="${BRIDGE_TOKEN:-$(node -e 'console.log(require("crypto").randomBytes(24).toString("hex"))')}"
if [[ "$PUSH_SECRET" == "1" && -n "$PUBLIC_URL" ]]; then
  if command -v supabase >/dev/null 2>&1; then
    echo "==> mise à jour des secrets Supabase (OPENCODE_BRIDGE_URL, OPENCODE_MODEL, OPENCODE_BRIDGE_TOKEN)"
    ( cd "$ROOT" && supabase secrets set \
        "OPENCODE_BRIDGE_URL=$PUBLIC_URL" \
        "OPENCODE_BRIDGE_TOKEN=$BRIDGE_TOKEN" \
        "OPENCODE_MODEL=$OPENCODE_MODEL" >/dev/null ) \
      && echo "    secrets à jour" \
      || echo "    échec secrets : lance 'supabase secrets set ...' à la main" >&2
  else
    echo "supabase CLI absent : pose les secrets à la main :" >&2
    echo "  supabase secrets set OPENCODE_BRIDGE_URL=$PUBLIC_URL OPENCODE_BRIDGE_TOKEN=$BRIDGE_TOKEN OPENCODE_MODEL=$OPENCODE_MODEL" >&2
  fi
fi

# --- 3. Pont (premier plan) -----------------------------------------------
echo "==> pont sur http://127.0.0.1:${BRIDGE_PORT} (modèle ${OPENCODE_MODEL})"
if [[ "$USE_TUNNEL" == "0" ]]; then
  BRIDGE_PORT="$BRIDGE_PORT" OPENCODE_URL="$OPENCODE_URL" OPENCODE_MODEL="$OPENCODE_MODEL" \
    BRIDGE_TOKEN="$BRIDGE_TOKEN" node "$HERE/bridge.mjs"
else
  # Avec tunnel : token obligatoire, mais on garde /health ouvert (pas de secret dedans).
  BRIDGE_PORT="$BRIDGE_PORT" OPENCODE_URL="$OPENCODE_URL" OPENCODE_MODEL="$OPENCODE_MODEL" \
    BRIDGE_TOKEN="$BRIDGE_TOKEN" node "$HERE/bridge.mjs" &
  BRIDGE_PID=$!
  wait "$BRIDGE_PID"
fi
