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
| `MQTT_HOST` | Broker MQTT 5 (EMQX Cloud Serverless) | `r1aa3902.ala.eu-central-1.emqxsl.com` | `vars` (wrangler.jsonc) |
| `MQTT_PORT` | Port TCP TLS (le plan Serverless n'expose pas 1883) | `8883` | `vars` (wrangler.jsonc) |
| `MQTT_USERNAME` | Utilisateur broker (droit publish `.../relays/+/cmd`, subscribe `.../ack` + `.../telemetry`) | — | `wrangler secret` |
| `MQTT_PASSWORD` | Mot de passe broker | = `MQTT_USERNAME` | `wrangler secret` |

Côté Flutter (web), le client se connecte en **WSS 8084** avec le chemin `/mqtt` :
`--dart-define=MQTT_WSS_PORT=8084` (défaut). En natif c'est `MQTT_TCP_PORT=8883`.

### Legacy Flespi

Les anciens noms restent lus en repli (`FLESPI_MQTT_HOST`, `FLESPI_MQTT_TCP_PORT`,
`FLESPI_MQTT_WORKER_TOKEN`) : le token sert alors de username **et** de password,
et la propriété `freeze_timeout` est envoyée uniquement à ce broker. L'ancien
broker est abandonné (tokens révoqués, cf. issue #37).

## Build & Deploy

### Infrastructure

| Ressource | Valeur |
|-----------|--------|
| Worker | `aricie-mqtt5-worker` — https://aricie-mqtt5-worker.smitthwillson1213.workers.dev |
| Container app | `aricie-mqtt5-worker-mqtt5container` |
| Registre | `registry.cloudflare.com` (poussé automatiquement par `wrangler deploy`) |
| Instance type | `basic` (1 GiB — `lite` crashait au chargement de Node + mqtt + supabase-js) |
| `sleepAfter` | `10m` — au-delà, le relais local WSL prend la main |
| Veille | `enforceSleep` (garde-fou 60 s) + SIGTERM → SIGKILL de secours, aucun cron keep-alive |
| DO | `Mqtt5Container` (`MQTT5_CONTAINER`), storage sqlite |
| Broker | EMQX Cloud Serverless — déploiement `dev`, région Europe, `r1aa3902.ala.eu-central-1.emqxsl.com` (8883 MQTT/TLS, 8084 WSS `/mqtt`) |

> Les services Azure (Container Apps, ACR, build-vm) ont été **supprimés** :
> l'abonnement a pris fin. Le build Docker passe par Docker local (WSL Debian),
> déclenché par `wrangler deploy` — plus aucune commande `az`.

### Veille (scale-to-zero)

Le container **ne doit pas tourner en permanence** : après `sleepAfter` (10 min)
sans requête, il doit passer en veille pour ne pas facturer l'instance.

1. le SDK (`sleepAfter = "600s"`) envoie `stop()` (SIGTERM) à l'expiration de
   l'activité ;
2. `index.js` installe des handlers **SIGTERM/SIGINT** — indispensable, le
   process étant **PID 1** du container, un signal sans handler est ignoré par
   le noyau et l'instance resterait active (bug constaté en prod : 8 h d'uptime
   malgré un `stop()` du SDK) ;
3. `worker.js` arme `enforceSleep` (tâche `schedule()` toutes les 60 s, réarmée
   à la construction du DO et à chaque `onStart()`) : il trace sa propre
   activité (`fetch` surcounté côté wrapper) et, si le compteur interne du SDK
   est bloqué (`inflightRequests > 0` après une requête annulée, ce qui rend
   `isActivityExpired()` toujours faux), il déclenche lui-même la veille ;
4. si l'instance vit encore 30 s après le SIGTERM (image ancienne), passe à
   `destroy()` (SIGKILL) → `LIVE INSTANCES` repasse à 0.

**Aucun cron keep-alive** (`triggers.crons` absent) : réveiller = une requête
HTTP sur le Worker, le relais local WSL/cloudflared assure la continuité pendant
la veille. Vérification :

```bash
wrangler containers list          # LIVE INSTANCES doit retomber à 0
wrangler tail                     # « veille forcée après 10 min sans requête »
```

### Secrets

Les secrets se posent sur le **Worker** ; `worker.js` les relaie au container via
`startConfig.env` :

```bash
cd workers/mqtt5-worker
wrangler secret put SUPABASE_URL
wrangler secret put SUPABASE_SERVICE_ROLE_KEY
wrangler secret put MQTT_USERNAME
wrangler secret put MQTT_PASSWORD
```

Basculer d'un broker à l'autre ne demande **aucun rebuild d'image** : `MQTT_HOST`
/ `MQTT_PORT` sont dans `vars` (wrangler.jsonc), les credentials dans les secrets.

Un secret posé **vide** est accepté par l'API mais produit une connexion refusée
côté broker. Vérifier avec `/_diag` : les longueurs de `SUPABASE_URL` et de
`MQTT_USERNAME` / `MQTT_PASSWORD` doivent être non nulles.

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

Bascule de broker (testée le 2026-10-24) : `MQTT_HOST` / `MQTT_PORT` dans `vars`,
`MQTT_USERNAME` / `MQTT_PASSWORD` en secrets, `wrangler deploy`, `/_stop`, puis
`/health` doit passer de `connecting` à `connected` en ~10 s.

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

## Test e2e sans broker cloud (EMQX en container)

La chaîne complète se valide sans compte chez un broker, avec un EMQX local :

```bash
# 1. broker
wsl -d Debian -u root -- bash -c "docker run -d --name emqx-local -p 1883:1883 emqx/emqx:5.8"

# 2. worker local pointé dessus (MQTT_TLS=false → mqtt:// en clair)
wsl -d Debian -u root -- bash -c \
  "docker run -d --name mqtt5-worker-local --network host --env-file /tmp/local-worker.env aricie/mqtt5-worker:local"
#    /tmp/local-worker.env : SUPABASE_*, MQTT_HOST=127.0.0.1, MQTT_PORT=1883,
#    MQTT_TLS=false, MQTT_USERNAME=test, MQTT_PASSWORD=test

# 3. boîtier simulé
wsl -d Debian -u root -- bash -c \
  "cd workers/test/box && MQTT_HOST=127.0.0.1 MQTT_PORT=1883 MQTT_TLS=false \
     MQTT_USERNAME=test MQTT_PASSWORD=test python3 box_esp32.py ESP32-A1B2C3D4"

# 4. une commande dans la file
curl -X POST "$SUPABASE_URL/rest/v1/device_commands" -H "apikey: $KEY" \
  -H "Content-Type: application/json" \
  -d '{"user_id":"...","box_id":"...","box_uid":"ESP32-A1B2C3D4","relay_index":2,
       "action":"on","status":"pending","requested_by":"e2e_test"}'

# 5. attendu : status acknowledged + ack_payload en < 2 s
```

Résultat du dernier passage (2026-10-24) : `sent` → `acknowledged` en 1 s,
`ack_payload = { success: true }`, `appliances.is_on` synchronisé, télémétrie
remontée dans `realtime_power` (155 messages).

## Troubleshooting

| Symptôme | Cause probable | Action |
|---|---|---|
| `Failed to start container` | Instance en échec ou `instance_type` trop petit | `/_stop` puis re-wake ; garder `basic`. Le vrai message est dans `/health` → `fatal_errors` |
| `/health` OK mais `app_loaded: false` | Import de `app.js` en échec | Lire `fatal_errors` (stack, 500 caractères) |
| `missing_env` non vide | Secrets absents ou posés vides | `wrangler secret put` puis `/_stop` pour forcer un nouveau start |
| `env_keys` sans les secrets | Secrets posés sur un autre Worker | `wrangler secret list`, comparer avec `/_diag` |
| `mqtt_state: closed` + `Bad User Name or Password` | Token Flespi expiré/révoqué | Régénérer le token (droit publish `.../relays/+/cmd`, subscribe `.../ack` et `.../telemetry`) |
| `/diag/supabase` ≠ 200 | URL/clé Supabase invalides | Re-générer la service role key (Supabase Dashboard → Settings → API) |
