# Communication MQTT / Worker / Flutter

## Architecture générale

```
┌─────────────────────────────────────────────────────────────────────┐
│                        SUPABASE (PostgreSQL + Realtime)             │
│                                                                     │
│  ┌──────────────────┐   ┌──────────────────┐   ┌────────────────┐  │
│  │  device_commands  │   │  realtime_power  │   │  appliances    │  │
│  │  (file d'attente) │   │  (telemetry)     │   │  (état)        │  │
│  └────────┬─────────┘   └──────────────────┘   └────────────────┘  │
│           │                                                         │
│  ┌────────┴─────────┐                                              │
│  │  agent_audit_logs │                                              │
│  └──────────────────┘                                              │
└─────────────────────────────────────────────────────────────────────┘
           ▲                          │                 ▲
           │ poll/claim               │ upsert          │ agent-orchestrator
           │ (SUPABASE_SERVICE_ROLE)  │ telemetry       │ (Edge Function)
           │                          │                 │
┌──────────┴──────────┐    ┌──────────┴──────────┐    │
│                     │    │                     │    │
│   MQTT5 WORKER      │    │   FLUTTER APP       │◄───┘
│   (Node.js/ACA)     │    │   (MqttService)     │
│                     │    │                     │
│  PUBLISH cmd        │    │  SUBSCRIBE          │
│  SUBSCRIBE ack      │    │  telemetry          │
│  SUBSCRIBE telemetry│    │  status             │
│                     │    │                     │
└──────────┬──────────┘    └──────────┬──────────┘
           │                          │
           │       BROKER FLESPI      │
           │    (mqtt.flespi.io)      │
           │     TCP TLS :8883        │
           │                          │
           └──────────┬───────────────┘
                      │
                      │ Topics MQTT 5
                      │
          ┌───────────┴───────────┐
          │                       │
          │   BOÎTIER ESP32       │
          │  (physique ou simulé) │
          │                       │
          │  PUBLISH telemetry    │
          │  PUBLISH status       │
          │  PUBLISH ack          │
          │  SUBSCRIBE cmd        │
          └───────────────────────┘
```

## Les 3 acteurs

| Acteur | Technologie | Rôle | Token Flespi |
|--------|------------|------|-------------|
| **Flutter App** | Dart / `mqtt5_client` | SUBSCRIBE `telemetry` + `status` — *ne publie jamais* | `FLESPI_MQTT_APP_TOKEN` |
| **MQTT5 Worker** | Node.js / `mqtt.js v5` (Azure Container Apps) | PUBLISH `cmd`, SUBSCRIBE `ack` + `telemetry` | `FLESPI_MQTT_WORKER_TOKEN` |
| **Boîtier ESP32** | C++ / PubSubClient (ou Python simulé) | PUBLISH `telemetry` + `status` + `ack`, SUBSCRIBE `cmd` | Token Flespi (dans le firmware) |

## Topics MQTT 5

| Topic | Direction | QoS | Description |
|-------|-----------|-----|-------------|
| `aricie/v1/boxes/{boxUid}/telemetry` | Boîtier → Flutter + Worker | 1 | Télémétrie (température, puissance par relais, kWh) |
| `aricie/v1/boxes/{boxUid}/status` | Boîtier → Flutter | 1 | État en ligne/offline au démarrage |
| `aricie/v1/boxes/{boxUid}/relays/{relayIndex}/cmd` | Worker → Boîtier | 1 | Commande (on/off) — *publish uniquement* |
| `aricie/v1/boxes/{boxUid}/relays/{relayIndex}/ack` | Boîtier → Worker | 1 | Acquittement de commande |

## Flux détaillés

### 1. Télémétrie (Boîtier → Flutter)

```
BOÎTIER                      BROKER FLESPI                FLUTTER APP
   │                             │                             │
   │── PUBLISH telemetry ───────►│                             │
   │   (toutes les 2-5s)        │── message ──────────────────►│
   │                             │   MqttService               │
   │                             │   parse BoxTelemetry        │
   │                             │   émet sur telemetryStream  │
   │                             │   → LiveConsumptionIndicator│
   │                             │   → MetricChart             │
```

**Ce que le boîtier envoie** :
```json
{
  "temperature": 22.5,
  "humidity": 45,
  "relays": [{"index": 1, "status": "on", "power_w": 150}],
  "power_w": 950,
  "kwh_total": 12.5,
  "kwh_total_per_relay": {"1": 3.2, "2": 0, "3": 9.3},
  "relay_power_w": {"1": 150, "2": 0, "3": 800}
}
```

**Ce que Flutter affiche** : consommation live, statut des appareils, graphiques.

### 2. Commande (Flutter → Boîtier)

La communication **ne se fait jamais directement**. Flutter ne publie pas sur MQTT. Toute commande passe par la file `device_commands` dans Supabase.

```
FLUTTER APP                  SUPABASE                         WORKER MQTT5                 BOÎTIER
   │                             │                                │                          │
   │ 1. Chat ou toggle UI        │                                │                          │
   │── POST agent-orchestrator──►│                                │                          │
   │   (SSE)                     │                                │                          │
   │                             │ 2. INSERT device_commands      │                          │
   │                             │   status = 'pending'           │                          │
   │◄── tool_result ──────────────                                │                          │
   │                             │                                │                          │
   │                             │ 3. Poll toutes les 1s          │                          │
   │                             │◄── claim pending ─────────────│                          │
   │                             │── status = 'processing' ──────►│                          │
   │                             │                                │                          │
   │                             │                        4. PUBLISH cmd                  │
   │                             │                        ──────── topic ────────────────►│
   │                             │                                │                          │
   │                             │                                │             5. Exécute    │
   │                             │                                │              et ACK      │
   │                             │                        ◄─────── PUBLISH ack ─────────────│
   │                             │                                │                          │
   │                             │ 6. UPDATE device_commands      │                          │
   │                             │   status = 'acknowledged'      │                          │
   │                             │◄── ───────────────────────────│                          │
```

**Étapes :**

1. **Flutter** envoie une requête à l'Edge Function `agent-orchestrator` (chat vocal ou toggle UI)
2. L'Edge Function crée une ligne dans `device_commands` avec `status = 'pending'`
3. Le **Worker MQTT5** (Node.js) interroge Supabase toutes les 1s, *claim* atomiquement la commande (`UPDATE ... SET status = 'processing' WHERE id = ? AND status = 'pending'`)
4. Le Worker publie sur MQTT : `aricie/v1/boxes/{boxUid}/relays/{relayIndex}/cmd` avec QoS 1
5. Le **boîtier** reçoit la commande, exécute l'action (on/off), publie un ACK sur `aricie/v1/boxes/{boxUid}/relays/{relayIndex}/ack`
6. Le Worker reçoit l'ACK, met à jour `device_commands` → `status = 'acknowledged'` et synchronise `appliances.is_on`

**Payload de commande** :
```json
{
  "command_id": "uuid-v4",
  "action": "off",
  "relay_index": 1,
  "appliance_name": "chauffe-eau",
  "source": "ai_agent",
  "issued_at": "2026-06-23T10:00:00Z"
}
```

**Payload d'ACK** :
```json
{
  "command_id": "uuid-v4",
  "success": true,
  "message": "Relay 1 turned OFF successfully"
}
```

### 3. Télémétrie → synchronisation BDD (Worker)

Le Worker souscrit aussi à `aricie/v1/boxes/+/telemetry`. Quand un boîtier envoie sa télémétrie :

1. Le Worker parse le message
2. Upsert dans `realtime_power` (table Supabase) — une ligne par `appliance_id`
3. Met à jour `appliances.is_on` si l'état du relais a changé (détection d'incohérence)

## Sécurité

| Principe | Détail |
|----------|--------|
| **Flutter ne publie jamais** | L'app ne peut pas envoyer de commandes MQTT directement. Tout passe par Supabase + Worker |
| **Double token Flespi** | App et Worker ont des tokens différents, avec des permissions minimales (SUBSCRIBE vs PUBLISH) |
| **Claim atomique** | `UPDATE ... WHERE status = 'pending'` — évite les doubles exécutions |
| **Timeout 30s** | Si pas d'ACK dans les 30s, le worker marque `status = 'timeout'` |
| **Webhook secret** | Le endpoint d'ACK du Worker est protégé par secret |
| **JWT Supabase** | L'Edge Function extrait `user_id` du token, jamais du body |

## Résumé des flux

```
                    ┌──────────────────────┐
                    │   FLUTTER APP         │
                    │  (MqttService)        │
                    │                       │
                    │  SUB: telemetry       │
                    │  SUB: status          │
                    │  (lecture seule)      │
                    └───────┬───────────────┘
                            │
                            │ agent-orchestrator (SSE)
                            ▼
                    ┌──────────────────────┐
                    │   SUPABASE            │
                    │  device_commands      │
                    │  realtime_power       │
                    │  appliances           │
                    └───────┬───────────────┘
                            │
                    ┌───────▼───────────────┐
                    │   WORKER NODE.JS      │
                    │  (Azure Container)    │
                    │                       │
                    │  Poll device_commands │
                    │  PUBLISH cmd          │
                    │  SUBSCRIBE ack        │
                    │  SUBSCRIBE telemetry  │
                    │  Upsert realtime_power│
                    └───────┬───────────────┘
                            │
                    ┌───────▼───────────────┐
                    │   BROKER FLESPI       │
                    │  mqtt.flespi.io:8883  │
                    └───────┬───────────────┘
                            │
                    ┌───────▼───────────────┐
                    │   BOÎTIER ESP32        │
                    │                       │
                    │  PUBLISH telemetry    │
                    │  SUBSCRIBE cmd         │
                    │  PUBLISH ack          │
                    └───────────────────────┘
```

## Files de référence

| Fichier | Contenu |
|---------|---------|
| `workers/mqtt5-worker/index.js` | Worker Node.js : polling, publish, ACK listener, telemetry upsert |
| `workers/mqtt5-worker/README.md` | Documentation déploiement, env vars, troubleshooting |
| `lib/services/mqtt_service.dart` | Service Flutter : connexion, souscription, stream télémetrie |
| `lib/services/agent_service.dart` | Client SSE : envoi messages → Edge Function → tool calling |
| `supabase/functions/agent-orchestrator/` | Edge Function : LLM + Policy Engine + device_commands |
| `workers/test/box/box_esp32.py` | Simulateur ESP32 en Python pour tests |
