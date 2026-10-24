# MQTT5 Worker — Aricie IoT Bridge

Worker Node.js persistant qui relaye les commandes IoT de la file d'attente Supabase (`device_commands`) vers les boîtiers via MQTT 5.0.

## Architecture

```
device_commands (pending)
  → Worker claim (UPDATE atomique status = 'processing' WHERE id = ? AND status = 'pending')
    → MQTT 5 publish QoS 1 sur aricie/v1/boxes/{boxUid}/relays/{relayIndex}/cmd
      → Boîtier exécute et publie ACK sur aricie/v1/boxes/{boxUid}/relays/{relayIndex}/ack
        → Worker update device_commands SET status = 'acknowledged'
      → Timeout 30s → status = 'timeout'
```

### Files

| File | Role |
|------|------|
| `index.js` | Bootstrap du container : monte `/health` AVANT tout import, charge `app.js` en dynamique, expose l'état MQTT |
| `app.js` | Logique métier (polling `device_commands` + MQTT publish + ACK listener + télémétrie) |
| `worker.js` | Wrapper Cloudflare (Durable Object `Mqtt5Container` + routes admin `/_stop`, `/_restart`, `/_diag`) |
| `wrangler.jsonc` | Config Cloudflare Containers (image, instance type, vars non secrètes) |
| `Dockerfile` | Image Docker node:22-alpine, `CMD ["node", "index.js"]` |
| `package.json` | Dépendances : `@supabase/supabase-js`, `mqtt`, `dotenv`, `@cloudflare/containers` |
| `scripts/deploy-cloudflare.sh` | Build + push + deploy Cloudflare |
| `scripts/run-local-failover.sh` | Relais local (WSL) actif quand le container Cloudflare dort |
| `.env` | Variables locales (ne pas commiter) |

### Pourquoi deux fichiers (`index.js` / `app.js`)

Le stdout d'un container Cloudflare n'est pas visible (cloudflare/containers#232) :
un crash au démarrage se traduit par un opaque `Failed to start container`. Le
bootstrap monte donc le serveur HTTP en premier, importe `app.js` en dynamique et
publie toute exception d'import dans `/health` (`fatal_errors`), avec `missing_env`
et `env_keys` (noms seulement, jamais les valeurs).

## Env vars

| Variable | Description | Default | Secret |
|----------|-------------|---------|--------|
| `SUPABASE_URL` | Supabase project URL | — | `wrangler secret` |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key (bypass RLS) | — | `wrangler secret` |
| `FLESPI_MQTT_WORKER_TOKEN` | Token Flespi pour auth MQTT | — | `wrangler secret` |
| `FLESPI_MQTT_HOST` | Broker MQTT host | `mqtt.flespi.io` | `vars` (wrangler.jsonc) |
| `FLESPI_MQTT_TCP_PORT` | Port TCP TLS | `8883` | `vars` (wrangler.jsonc) |

## Build & Deploy

### Infrastructure

| Ressource | Valeur |
|-----------|--------|
| Worker | `aricie-mqtt5-worker` — https://aricie-mqtt5-worker.smitthwillson1213.workers.dev |
| Container app | `aricie-mqtt5-worker-mqtt5container` |
| Registre | `registry.cloudflare.com` (poussé automatiquement par `wrangler deploy`) |
| Instance type | `basic` (1 GiB — `lite` crashait au chargement de Node + mqtt + supabase-js) |
| `sleepAfter` | `10m` — au-delà, le relais local WSL prend la main |
| DO | `Mqtt5Container` (`MQTT5_CONTAINER`), storage sqlite |

> Les services Azure (Container Apps, ACR, build-vm) ont été **supprimés** :
> l'abonnement a pris fin. Le build Docker passe par Docker local (WSL Debian),
> déclenché par `wrangler deploy` — plus aucune commande `az`.

### Secrets

Les secrets se posent sur le **Worker** ; `worker.js` les relaie au container via
`startConfig.env` :

```bash
cd workers/mqtt5-worker
wrangler secret put SUPABASE_URL
wrangler secret put SUPABASE_SERVICE_ROLE_KEY
wrangler secret put FLESPI_MQTT_WORKER_TOKEN
```

Un secret posé **vide** est accepté par l'API mais produit une connexion refusée
côté broker. Vérifier avec `/_diag` : les longueurs attendues sont 40 (URL),
219 (service role) et 64 (token Flespi).

### Déploiement

```bash
# complet : build Docker + push + deploy Worker/Container
./scripts/deploy-cloudflare.sh

# deploy seul (image inchangée)
SKIP_BUILD=1 ./scripts/deploy-cloudflare.sh

# sous WSL (Docker n'est pas dans le PATH Windows)
wsl -d Debian -u root -- bash -c "cd '<repo>/workers/mqtt5-worker' && wrangler deploy"
```

`wrangler deploy` construit l'image depuis `containers[].image` (`./Dockerfile`),
la pousse sur `registry.cloudflare.com` puis met à jour l'application.

### Après un déploiement

Un container déjà `running` **ne réapplique pas** `envVars` : il faut le stopper
pour repartir de zéro avec la nouvelle config.

```bash
curl https://aricie-mqtt5-worker.smitthwillson1213.workers.dev/_stop
curl https://aricie-mqtt5-worker.smitthwillson1213.workers.dev/_restart  # stop + start avec envVars explicites
curl https://aricie-mqtt5-worker.smitthwillson1213.workers.dev/_diag     # longueurs des secrets vus par le Worker
```

## Vérification

```bash
curl https://aricie-mqtt5-worker.smitthwillson1213.workers.dev/health
curl https://aricie-mqtt5-worker.smitthwillson1213.workers.dev/diag/supabase
```

`/health` répond **toujours** 200 (même app cassée) ; le diagnostic est dans le corps :

```json
{
  "status": "ok",
  "app_loaded": true,
  "mqtt_state": "connected",
  "mqtt_last_error": null,
  "missing_env": [],
  "fatal_errors": [],
  "stats": { "telemetryMessages": 3, "acksProcessed": 1, "commandsSent": 2 }
}
```

`/diag/supabase` doit renvoyer `{"http_status":200,...}` : c'est la preuve que le
container joint Supabase (sinon le polling `device_commands` échoue en silence).

## Troubleshooting

| Symptôme | Cause probable | Action |
|---|---|---|
| `Failed to start container` | Instance en échec ou `instance_type` trop petit | `/_stop` puis re-wake ; garder `basic`. Le vrai message est dans `/health` → `fatal_errors` |
| `/health` OK mais `app_loaded: false` | Import de `app.js` en échec | Lire `fatal_errors` (stack, 500 caractères) |
| `missing_env` non vide | Secrets absents ou posés vides | `wrangler secret put` puis `/_stop` pour forcer un nouveau start |
| `env_keys` sans les secrets | Secrets posés sur un autre Worker | `wrangler secret list`, comparer avec `/_diag` |
| `mqtt_state: closed` + `Bad User Name or Password` | Token Flespi expiré/révoqué | Régénérer le token (droit publish `.../relays/+/cmd`, subscribe `.../ack` et `.../telemetry`) |
| `/diag/supabase` ≠ 200 | URL/clé Supabase invalides | Re-générer la service role key (Supabase Dashboard → Settings → API) |
