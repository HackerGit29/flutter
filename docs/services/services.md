# Services Layer

Infrastructure services for external communication.

## MqttService
Service IoT connecté au broker flespi en MQTT 5.0.

- **Broker**: `mqtt.flespi.io` — TCP TLS `:8883` (natif), WSS `:443` (web)
- **Auth**: Token flespi comme `username`, password vide
- **QoS**: `atLeastOnce` (QoS 1) maximum
- **Package**: `mqtt5_client ^4.17.1`

### Implémentations
| Client | Transport | Plateforme |
|---|---|---|
| `Mqtt5NativeClient` | TCP TLS 8883 | Mobile/Desktop (non-web) |
| `Mqtt5WebClient` | WSS 443 | Web (browser) |

### Topics MQTT 5 définitifs
| Topic | Direction | QoS |
|---|---|---|
| `aricie/v1/boxes/{boxUid}/telemetry` | Boîtier → App | 1 |
| `aricie/v1/boxes/{boxUid}/status` | Boîtier → App | 1 |
| `aricie/v1/boxes/{boxUid}/relays/{relayIndex}/cmd` | Worker → Boîtier | 1 |
| `aricie/v1/boxes/{boxUid}/relays/{relayIndex}/ack` | Boîtier → Worker | 1 |

**Flutter lit uniquement** `telemetry` et `status`. Les commandes passent par `agent-orchestrator` → `device_commands` → Worker MQTT.

### Flux télémétrie
1. Boîtier publie `BoxTelemetry` JSON sur `aricie/v1/boxes/{boxUid}/telemetry`
2. `MqttService._processMessages` parse → `BoxTelemetry.fromJson()`
3. Émet sur `telemetryStream` (broadcast)
4. `latestTelemetry` garde la dernière valeur synchrone

### Commande directe (debug uniquement)
`sendDebugControlCommand(boxUid, relayIndex, action)` — réservé au mode debug (`kDebugMode`). En production, toute commande passe par l'agent IA.

### Initialisation
```dart
await mqttService.initialize(
  boxUid: boxUid,
  mqttToken: tokenFlespi,
);
```

### Modèles associés
- `BoxTelemetry` + `RelayState` : contrat unique télémétrie boîtier.

## AuthService
High-level authentication wrapper.
- **Security**: Migrated sensitive user data from `SharedPreferences` to `FlutterSecureStorage`.

## AgentService (v2 — SSE + Edge Function)
Remplace l'ancienne intégration directe Flowise.

### Architecture
```
Flutter Client
  → AgentService (SSE client)
    → POST /functions/v1/agent-orchestrator (JWT + message)
      → Supabase Edge Function (Deno)
        → Azure OpenAI GPT-4o (tool calling + streaming)
        → Policy Engine (ownership + RBAC + rate limit)
        → device_commands (file d'attente)
        → Audit log
        → SSE response typée
```

### Flux SSE
| Event | Description |
|---|---|
| `connected` | Confirmation de connexion, contient `user_id` |
| `token` | Token de réponse textuelle (streaming) |
| `tool_pending` | Début d'exécution d'une action (allumage, extinction...) |
| `tool_result` | Résultat de l'action (succès/échec) |
| `error` | Erreur de traitement |
| `done` | Fin du flux |

### Endpoint
- **Edge Function**: `{supabaseUrl}/functions/v1/agent-orchestrator`
- **Auth**: JWT Supabase dans `Authorization: Bearer <token>`
- **Body**: `{ message, session_id, locale, mode }`

### Tools exposés au LLM
| Tool | Description | Paramètre |
|---|---|---|
| `turn_on_appliance` | Allumer un appareil | `appliance_name` (nom métier) |
| `turn_off_appliance` | Éteindre un appareil | `appliance_name` (nom métier) |
| `get_realtime_consumption` | Consommation temps réel | `appliance_name` (optionnel) |
| `get_device_status` | État d'un appareil | `appliance_name` |
| `get_energy_history` | Historique de consommation | `appliance_name`, `period` |

### Sécurité
- `user_id` extrait du JWT Supabase, jamais du body client
- Le LLM ne manipule que des noms métier, les IDs sont résolus côté backend
- Toute action passe par le Policy Engine (ownership + rate limit)
- Audit complet dans `agent_audit_logs`

## VoiceService
Service de reconnaissance vocale (STT) et synthèse vocale (TTS).

- **STT**: `speech_to_text` (reconnaissance vocale française)
- **TTS**: `flutter_tts` (synthèse vocale française)
- **Permissions**: Microphone via `permission_handler`

### Modes
- **Voice input**: Microphone → STT → texte → AgentService → réponse
- **Voice output** (mode vocal): AgentService → streaming SSE → TTS
- **Voice mode complet** (toggle dans l'AppBar) : STT + TTS en boucle

## Worker MQTT 5
Worker Node.js persistant avec `mqtt.js v5` (protocolVersion 5).

```
device_commands (pending)
  → Worker claim (idempotent)
    → MQTT 5 publish QoS 1 (messageExpiryInterval: 30s)
      → Boîtier ACK (topic ack)
        → status = acknowledged
      → Timeout 30s → status = timeout
```

- **Claim atomique** : `UPDATE device_commands SET status = 'processing' WHERE id = pending.id AND status = 'pending'`
- **ACK listener** : subscribe `aricie/v1/boxes/+/relays/+/ack`
- **Timeout** : `markTimeoutCommands()` toutes les 10s
- **Variables `.env`** : `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `FLESPI_MQTT_HOST`, `FLESPI_MQTT_TCP_PORT`, `FLESPI_MQTT_WORKER_TOKEN`

### Commande MQTT 5 publiée
```json
{
  "command_id": "uuid",
  "action": "off",
  "relay_index": 1,
  "appliance_name": "chauffe-eau",
  "source": "ai_agent",
  "issued_at": "2026-06-23T10:00:00Z"
}
```

### ACK boîtier
```json
{
  "command_id": "uuid",
  "box_uid": "BOX_001",
  "relay_index": 1,
  "action": "off",
  "success": true,
  "state": "off",
  "ack_at": "2026-06-23T10:00:02Z"
}
```

## NotificationService
Handles local and push notifications for system alerts and reminders.
