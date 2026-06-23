# Aricie Agent IA — Architecture

## Architecture cible

```
┌──────────────────────────────────────────────────────────────┐
│  Flutter Client                                               │
│  ┌──────────┐ ┌────────────┐ ┌─────────────┐                │
│  │ Chat UI  │ │ Voice STT  │ │ SSE Stream  │                │
│  │ (widgets)│ │ (speech_to │ │ Reader      │                │
│  │          │ │  _text)    │ │             │                │
│  └────┬─────┘ └─────┬──────┘ └──────┬──────┘                │
│       │             │               │                        │
│       └──────┬──────┴──────┬────────┘                        │
│              ▼             ▼                                 │
│  ┌────────────────────────────────────┐                      │
│  │ AgentService (Flutter)             │                      │
│  │ • POST /functions/v1/agent         │                      │
│  │ • JWT Supabase (Authorization)     │                      │
│  │ • SSE stream → progressive UI     │                      │
│  │ • VoiceService (STT/TTS)          │                      │
│  └────────────────┬───────────────────┘                      │
└───────────────────┼──────────────────────────────────────────┘
                    │ POST + JWT
                    ▼
┌──────────────────────────────────────────────────────────────┐
│  Supabase Edge Function : agent-orchestrator                  │
│                                                               │
│  1. AUTH : parse JWT → auth.uid (IGNORE body.user_id)        │
│  2. RAG : pgvector WHERE owner_id = auth.uid                 │
│  3. Contexte opérationnel : appliances scope user             │
│  4. Azure OpenAI GPT-4o : tool calling                        │
│     • Le LLM ne manipule que des noms métier                  │
│     • Il propose une intention, ne choisit jamais les IDs     │
│  5. Policy Engine :                                           │
│     • Resolve appliance_name → appliance_id → relay_index     │
│     • Ownership vérifié en base (.eq("user_id", requesterId)) │
│     • Rate limit : 10 commandes/minute par boîtier            │
│  6. INSERT INTO device_commands (safe queue)                  │
│  7. Audit log → agent_audit_logs                              │
│  8. SSE streaming : token / tool_pending / tool_result / done │
└──────────────────────┬────────────────────────────────────────┘
                       │
          ┌────────────┴────────────┐
          ▼                         ▼
┌──────────────────┐    ┌────────────────────────┐
│ pgvector (RAG)    │    │ device_commands        │
│ owner_id scoped   │    │ (file d'attente)       │
│ FAQ + docs user   │    │ pending → sent → ack   │
└──────────────────┘    └───────────┬────────────┘
                                    │ Database Webhook
                                    ▼
                          ┌────────────────────────┐
                          │ Worker MQTT             │
                          │ /functions/v1/mqtt-     │
                          │ worker                  │
                          │                         │
                          │ 1. Vérifie secret       │
                          │ 2. Vérifie idempotence  │
                          │ 3. Publie MQTT          │
                          │ 4. Update status        │
                          └────────────────────────┘
```

## Règles de sécurité

### 1. `user_id` vient uniquement du JWT Supabase
- Pas du body Flutter
- Pas d'un paramètre manipulable côté client
- `auth.ts` : `supabase.auth.getUser()` depuis le token Bearer

### 2. Le LLM ne voit que des noms métier
- `chauffe-eau`, `lampe salon`, `climatiseur`
- Pas de `box_uid`, `device_uid`, `mqtt_topic`, `relay_index`, `owner_id`
- Les tools ne prennent que `appliance_name` en paramètre

### 3. Les actions passent toujours par le Policy Engine
- Résolution appareil → ownership → rate limit → audit
- Aucune action directe sans vérification

### 4. `device_commands` sert de file d'attente
- L'agent ne publie jamais directement MQTT
- Le Worker MQTT consomme la file
- Statut : `pending → sent → acknowledged/failed`

### 5. SSE typé
| Event | Direction | Contenu |
|---|---|---|
| `connected` | Server → Client | `user_id` |
| `token` | Server → Client | Texte en streaming |
| `tool_pending` | Server → Client | Action en cours |
| `tool_result` | Server → Client | Résultat succès/échec |
| `error` | Server → Client | Message d'erreur |
| `done` | Server → Client | Fin du flux |

## Secrets (dashboard Supabase, jamais côté Flutter)

```
AZURE_OPENAI_ENDPOINT           → https://<resource>.openai.azure.com
AZURE_OPENAI_API_KEY            → <clé API>
AZURE_OPENAI_DEPLOYMENT         → gpt-4o
AZURE_OPENAI_API_VERSION        → 2024-10-21
AZURE_OPENAI_EMBEDDING_DEPLOYMENT → text-embedding-3-small
MQTT_HOST                       → broker.aricie.energy
MQTT_PORT                       → 8883
WEBHOOK_SECRET                  → clé partagée pour le webhook
```

## Tables créées

| Table | Type | Description |
|---|---|---|
| `device_commands` | PostgreSQL | File d'attente des commandes appareil |
| `agent_audit_logs` | PostgreSQL | Journal immuable des actions de l'agent |
| `chat_embeddings` | pgvector | Embeddings RAG scope par `owner_id` |

### RPC Functions
- `match_user_embeddings(query_embedding, requester_id, match_count)` → recherche vectorielle scopée
- `get_user_appliances_context(requester_id)` → contexte opérationnel JSON

## Outils LLM (Azure OpenAI GPT-4o tools)

```json
[
  { "name": "turn_on_appliance",     "params": { "appliance_name": "string" } },
  { "name": "turn_off_appliance",    "params": { "appliance_name": "string" } },
  { "name": "get_realtime_consumption", "params": { "appliance_name": "string" } },
  { "name": "get_device_status",     "params": { "appliance_name": "string" } },
  { "name": "get_energy_history",    "params": { "appliance_name": "string", "period": "day|week|month|year" } }
]
```

## Testing requis

1. User A → son appareil → autorisé
2. User A → appareil de User B → bloqué
3. "Éteins le chauffe-eau" → device_commands pending
4. Worker MQTT → commande sent
5. Commande dupliquée → pas de double publication
6. RAG User A → jamais document User B
7. Voice → STT → agent → SSE → TTS
8. Azure OpenAI indisponible → erreur UI propre

## Évolution future

- **Azure Realtime Audio** (WebRTC) pour voix basse latence
- **Worker MQTT persistant** si le broker ne supporte pas HTTP API
- **Dashboard admin** pour supervision des logs agent
- **Feedback loop** : good/bad sur réponses agent
