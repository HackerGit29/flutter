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
| `index.js` | Worker principal (polling + MQTT publish + ACK listener) |
| `Dockerfile` | Image Docker node:22-alpine |
| `package.json` | Dépendances : `@supabase/supabase-js`, `mqtt`, `dotenv` |
| `.env` | Variables locales (ne pas commiter) |

## Env vars

| Variable | Description | Default | Secret |
|----------|-------------|---------|--------|
| `SUPABASE_URL` | Supabase project URL | — | secretRef (supabase-url) |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key (bypass RLS) | — | secretRef (supabase-key) |
| `FLESPI_MQTT_WORKER_TOKEN` | Token Flespi pour auth MQTT | — | secretRef (flespi-token) |
| `FLESPI_MQTT_HOST` | Broker MQTT host | `mqtt.flespi.io` | plain env |
| `FLESPI_MQTT_TCP_PORT` | Port TCP TLS | `8883` | plain env |

## Build & Deploy

### Infrastructure

| Resource | Valeur |
|----------|--------|
| ACR | `paossimb7935acr.azurecr.io` |
| Resource group | `rg-paossimb-7935` |
| Container App | `mqtt5-worker` |
| CA Environment | `cae-paossimb-7935` |
| Région | `francecentral` |
| Build VM | `68.210.96.129` (austriaeast, Standard_B2ats_v2) |
| SSH key | `~/.ssh/id_rsa` |

### Build VM

La VM `build-vm` (austriaeast) est utilisée pour builder l'image Docker car ACR Tasks est bloqué par la politique Azure for Students.

**État actuel : Running.** Ne pas arrêter (ou la redémarrer si arrêtée).

Connexion :
```bash
ssh -i ~/.ssh/id_rsa azureuser@68.210.96.129
```

Docker est pré-installé. Le répertoire de travail sur la VM est `/home/azureuser/mqtt5-worker/`.

### Déploiement automatisé

```bash
# Full build + deploy
pwsh scripts/azure/deploy-mqtt5-worker.ps1

# Build only (test)
pwsh scripts/azure/deploy-mqtt5-worker.ps1 -SkipDeploy

# Deploy only (reuse last image)
pwsh scripts/azure/deploy-mqtt5-worker.ps1 -SkipBuild
```

### Déploiement manuel étape par étape

```bash
# 1. Sync source
scp -i ~/.ssh/id_rsa -r workers/mqtt5-worker/* azureuser@68.210.96.129:/home/azureuser/mqtt5-worker/

# 2. Build image
ssh -i ~/.ssh/id_rsa azureuser@68.210.96.129 "
  cd /home/azureuser/mqtt5-worker
  sudo docker build -t paossimb7935acr.azurecr.io/mqtt5-worker:latest .
"

# 3. Push to ACR
$acrPwd = az acr credential show --name paossimb7935acr --resource-group rg-paossimb-7935 --query "passwords[0].value" -o tsv
ssh -i ~/.ssh/id_rsa azureuser@68.210.96.129 "
  sudo docker login paossimb7935acr.azurecr.io -u paossimb7935acr -p '$acrPwd'
  sudo docker push paossimb7935acr.azurecr.io/mqtt5-worker:latest
"

# 4. Restart Container App
az containerapp update --name mqtt5-worker --resource-group rg-paossimb-7935 --image paossimb7935acr.azurecr.io/mqtt5-worker:latest

# 5. Verify
az containerapp logs show --name mqtt5-worker --resource-group rg-paossimb-7935 --type console --tail 20
```

### Création from scratch (uniquement si le Container App n'existe pas)

```bash
az containerapp create `
  --name mqtt5-worker `
  --resource-group rg-paossimb-7935 `
  --environment cae-paossimb-7935 `
  --image paossimb7935acr.azurecr.io/mqtt5-worker:latest `
  --registry-server paossimb7935acr.azurecr.io `
  --registry-username paossimb7935acr `
  --registry-password (az acr credential show --name paossimb7935acr --resource-group rg-paossimb-7935 --query "passwords[0].value" -o tsv) `
  --secrets `
    supabase-url="https://eevjozgobudwnbvjecnw.supabase.co" `
    supabase-key="<SERVICE_ROLE_KEY>" `
    flespi-token="<FLESPI_TOKEN>" `
  --env-vars `
    SUPABASE_URL="secretref:supabase-url" `
    SUPABASE_SERVICE_ROLE_KEY="secretref:supabase-key" `
    FLESPI_MQTT_WORKER_TOKEN="secretref:flespi-token" `
    FLESPI_MQTT_HOST="mqtt.flespi.io" `
    FLESPI_MQTT_TCP_PORT="8883" `
  --ingress internal `
  --target-port 80 `
  --min-replicas 1 --max-replicas 1
```

## Vérification

```bash
# Logs temps réel
az containerapp logs show --name mqtt5-worker --resource-group rg-paossimb-7935 --type console --tail 100

# Révisions
az containerapp revision list --name mqtt5-worker --resource-group rg-paossimb-7935 -o table
```

## Logs de démarrage OK

```
[WORKER] mqtt5-worker-1 started in MQTT 5 mode
[MQTT5] Connected to mqtts://mqtt.flespi.io:8883
[MQTT5] Subscribed to ACK topics
```

## Troubleshooting

| Symptôme | Cause probable | Action |
|---|---|---|
| CrashLoopBackOff | Secrets manquants ou invalides | `az containerapp logs show --tail 50`, vérifier les secrets via `az containerapp show --query "properties.template.containers[0].env"`, re-deployer |
| `Failed to connect to broker` | Token Flespi invalide/expiré | Vérifier `FLESPI_MQTT_WORKER_TOKEN`, tester avec `mosquitto_sub -h mqtt.flespi.io -p 8883 -t test -u <token>` |
| Supabase errors | URL ou service_role_key invalides | Re-générer la clé dans Supabase Dashboard → Settings → API |
| `Ready = False` | Normal (worker background, pas de HTTP) | Vérifier les logs. Si le worker tourne et traite des commandes, c'est OK |
