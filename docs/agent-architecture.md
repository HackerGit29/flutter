# Aricie Agent IA — Architecture

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  Flutter Client                                                   │
│  ┌──────────┐ ┌────────────┐ ┌─────────────┐                    │
│  │ Chat UI  │ │ Voice STT  │ │ SSE Stream  │                    │
│  │ (widgets)│ │ (speech_to │ │ Reader      │                    │
│  │          │ │  _text)    │ │             │                    │
│  └────┬─────┘ └─────┬──────┘ └──────┬──────┘                    │
│       │             │               │                            │
│       └──────┬──────┴──────┬────────┘                            │
│              ▼             ▼                                     │
│  ┌─────────────────────────────────────────────┐                 │
│  │ AgentService (Flutter)                       │                 │
│  │ • supabase.functions.invoke('ai-chat', ...)  │                 │
│  │ • JWT Supabase (Authorization)               │                 │
│  │ • Réponse JSON → UI et/ou VoiceService TTS   │                 │
│  │ • VoiceService : STT input → TTS output      │                 │
│  └────────────────┬────────────────────────────┘                 │
└───────────────────┼──────────────────────────────────────────────┘
                    │ POST + JWT
                    ▼
┌──────────────────────────────────────────────────────────────────┐
│  Supabase Edge Function : ai-chat                                │
│                                                                   │
│  1. Reçoit { messages, temperature, max_tokens }                  │
│  2. Lit AZURE_OPENAI secrets via Deno.env.get()                   │
│  3. POST /openai/deployments/Phi-4-mini-instruct/chat/completions│
│  4. Retourne { success, content, raw }                            │
└──────────────────────────┬───────────────────────────────────────┘
                           │ fetch() + api-key
                           ▼
┌──────────────────────────────────────────────────────────────────┐
│  Azure AI Foundry : Phi-4-mini-instruct (GlobalStandard)         │
│  • Endpoint : paossimb-7935-resource.cognitiveservices.azure.com │
│  • API version : 2024-06-01                                      │
│  • Rate limit : 1 req/s, 400 tokens/min                         │
└──────────────────────────────────────────────────────────────────┘
```

## Architecture avancée (agent-orchestrator)

```
┌──────────────────────────────────────────────────────────────┐
│  Flutter Client                                               │
│  • AgentService (SSE via supabase.functions.invoke)          │
└───────────────────┬──────────────────────────────────────────┘
                    ▼
┌──────────────────────────────────────────────────────────────┐
│  Supabase Edge Function : agent-orchestrator                  │
│                                                               │
│  1. AUTH : parse JWT → auth.uid (IGNORE body.user_id)        │
│  2. RAG : pgvector WHERE owner_id = auth.uid                 │
│  3. Contexte opérationnel : appliances scope user             │
│  4. Phi-4-mini-instruct : tool calling                        │
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
AZURE_OPENAI_ENDPOINT             → https://paossimb-7935-resource.cognitiveservices.azure.com/
AZURE_OPENAI_API_KEY              → <clé API Azure>
AZURE_OPENAI_DEPLOYMENT           → Phi-4-mini-instruct
AZURE_OPENAI_API_VERSION          → 2024-06-01
AZURE_OPENAI_EMBEDDING_DEPLOYMENT → text-embedding-3-large-aricie
AZURE_OPENAI_EMBEDDING_DIMENSIONS → 1536
FLESPI_MQTT_HOST                  → mqtt.flespi.io
FLESPI_MQTT_TCP_PORT              → 8883
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

## Flutter → Edge Function (ai-chat)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Future<String> askAricie(String userMessage) async {
  final session = supabase.auth.currentSession;

  final response = await supabase.functions.invoke(
    'ai-chat',
    body: {
      'messages': [
        {
          'role': 'system',
          'content': '''
Tu es Aricie, un assistant énergétique IoT.
Réponds en français.
Si l'utilisateur demande une action sur un appareil, n'invente jamais.
Demande confirmation si l'action est ambiguë.
''',
        },
        {
          'role': 'user',
          'content': userMessage,
        },
      ],
      'temperature': 0.2,
      'max_tokens': 500,
    },
    headers: {
      if (session?.accessToken != null)
        'Authorization': 'Bearer ${session!.accessToken}',
    },
  );

  final data = response.data;

  if (data == null || data['success'] != true) {
    throw Exception(data?['error'] ?? 'Erreur inconnue');
  }

  return data['content'] as String? ?? '';
}
```

## Sortie JSON structurée pour commandes IoT

```dart
const aricieSystemPrompt = '''
Tu es Aricie, un assistant IoT énergétique.

Tu dois répondre uniquement avec un JSON valide.

Format obligatoire :
{
  "type": "chat" | "device_command",
  "message": "réponse utilisateur en français",
  "intent": "none" | "turn_on" | "turn_off" | "status",
  "device_name": string | null,
  "room": string | null,
  "confidence": number
}

Règles :
- Si l'utilisateur veut allumer ou éteindre un appareil, utilise type = "device_command".
- Si l'appareil est ambigu, utilise type = "chat" et demande une précision.
- N'invente jamais un appareil.
- Ne produis jamais de texte hors du JSON.
''';
```

## Outils LLM (agent-orchestrator, Phi-4-mini-instruct tools)

```json
[
  { "name": "turn_on_appliance",     "params": { "appliance_name": "string" } },
  { "name": "turn_off_appliance",    "params": { "appliance_name": "string" } },
  { "name": "get_realtime_consumption", "params": { "appliance_name": "string" } },
  { "name": "get_device_status",     "params": { "appliance_name": "string" } },
  { "name": "get_energy_history",    "params": { "appliance_name": "string", "period": "day|week|month|year" } }
]
```

## Résumé des déploiements Azure

| Modèle | Nom du déploiement | SKU | Status |
|--------|-------------------|-----|--------|
| `Phi-4-mini-instruct` | `Phi-4-mini-instruct` | GlobalStandard (1) | ✅ Déployé |
| `gpt-4o-transcribe` | `gpt-4o-transcribe-aricie` | GlobalStandard (1) | ✅ Déployé |
| `gpt-4o-transcribe-diarize` | `gpt-4o-transcribe-diarize-aricie` | GlobalStandard (1) | ✅ Déployé |
| `text-embedding-3-large` | `text-embedding-3-large-aricie` | Standard (1) | ✅ Déployé |

| Ressource | Endpoint | Usage |
|-----------|----------|-------|
| `paossimb-7935-resource` (Azure OpenAI) | `cognitiveservices.azure.com` | Chat (Phi-4), STT (gpt-4o-transcribe), Embeddings |
| `paossimb-speech-7935` (Speech Services) | `francecentral.tts.speech.microsoft.com` | TTS (Neural) — Free F0 |

## Voice Mode Architecture

```
Flutter Voice Mode
  ┌─────────────────────────────────────────────┐
  │ 1. Appuie sur le micro → record audio (WAV) │
  │ 2. POST /functions/v1/transcribe-audio      │
  │ 3. Azure gpt-4o-transcribe → texte          │
  │ 4. POST /functions/v1/ai-chat               │
  │    (ou agent-orchestrator pour tool calling) │
  │ 5. Réponse texte → POST /functions/v1/      │
  │    text-to-speech                           │
  │ 6. Azure Neural TTS → audio MP3            │
  │ 7. Lecture audio via audioplayers           │
  │ 8. Auto-relance écoute (boucle vocale)      │
  └─────────────────────────────────────────────┘

Edge Functions:
  • transcribe-audio : audio → gpt-4o-transcribe → texte
  • text-to-speech    : texte → Azure Neural TTS → audio MP3
  • ai-chat           : messages → Phi-4-mini-instruct → réponse
  • agent-orchestrator : message + tools → Phi-4-mini-instruct → SSE
```

## Testing requis

1. User A → son appareil → autorisé
2. User A → appareil de User B → bloqué
3. "Éteins le chauffe-eau" → device_commands pending
4. Worker MQTT → commande sent
5. Commande dupliquée → pas de double publication
6. RAG User A → jamais document User B
7. Voice → STT → agent → SSE → TTS
8. Azure Phi-4-mini-instruct indisponible → erreur UI propre

## Évolution future

- **Azure Realtime Audio** (WebRTC) pour voix basse latence
- **Worker MQTT persistant** si le broker ne supporte pas HTTP API
- **Dashboard admin** pour supervision des logs agent
- **Feedback loop** : good/bad sur réponses agent
- **Retour à GPT-4o** dès que le quota est approuvé (changer un seul secret : `AZURE_OPENAI_DEPLOYMENT`)
