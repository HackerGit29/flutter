# Aricie Agent IA — Architecture

> **État (oct. 2026)** — le chemin **principal** est `agent-orchestrator`
> (SSE + tool calling). La fonction `ai-chat` est **legacy** (réponse JSON
> simple, encore branchée sur Azure). La chaîne LLM du chat / tool-calling est
> **OpenCode bridge → DeepSeek → Cloudflare Workers AI** (`llm.ts`). Les
> **embeddings RAG** et la **voix (STT/TTS)** sont **encore sur Azure**
> (abonnement terminé → migration hors Azure en attente).

## Architecture avancée (agent-orchestrator) — chemin principal

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
│  3. Contexte opérationnel : appliances + subscription scope   │
│  4. LLM (llm.ts) : chaîne bridge → deepseek → cloudflare      │
│     • tool calling ; le LLM ne voit que des noms métier       │
│     • Il propose une intention, ne choisit jamais les IDs     │
│  5. Policy Engine :                                           │
│     • Resolve appliance_name → appliance_id → relay_index     │
│     • Ownership vérifié en base (.eq("user_id", requesterId)) │
│     • Rate limit : 10 commandes/minute par boîtier            │
│     • Criticalité élevée → confirmation modale obligatoire    │
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
│ embeddings Azure  │    │ pending → sent → ack   │
└──────────────────┘    └───────────┬────────────┘
                                    │ Database Webhook
                                    ▼
                          ┌────────────────────────┐
                          │ Worker MQTT5           │
                          │ (Cloudflare Containers)│
                          │ 1. Idempotence         │
                          │ 2. Publie MQTT         │
                          │ 3. Update status       │
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

### 5. SSE typé (v1.4.1)
| Event | Direction | Contenu |
|---|---|---|
| `connected` | Server → Client | `user_id` |
| `token` | Server → Client | Texte en streaming (seul contenu visible dans l'UI) |
| `tool_pending` | Server → Client | Action en cours (peut contenir `requires_confirmation: true` pour appareils critiques) — **masqué dans l'UI** |
| `tool_result` | Server → Client | Résultat succès/échec — **masqué dans l'UI** |
| `error` | Server → Client | Message d'erreur |
| `done` | Server → Client | Fin du flux |

L'utilisateur ne voit que les événements `token` (réponse du LLM) et `error`. Les événements `tool_pending` / `tool_result` sont traités en arrière-plan.

### 6. Confirmation structurée (confirmed_tool_call)
Pour les actions critiques (chauffe-eau, climatiseur, four, cuisinière), le backend demande une confirmation modale via `tool_pending` avec `requires_confirmation: true`. L'utilisateur confirme dans l'UI, et Flutter renvoie un `confirmed_tool_call` structuré (contournant le LLM) directement au backend pour exécution, sans risque de mauvaise interprétation par le modèle.

Le `confirmed_tool_call` inclut `confirmed: true` dans les arguments pour éviter la boucle infinie de confirmation. Après exécution, le LLM génère une réponse streamée pour confirmer l'action à l'utilisateur.

## Secrets (dashboard Supabase, jamais côté Flutter)

### Chaîne LLM du chat / tool-calling (`llm.ts`)
```
OPENCODE_BRIDGE_URL   → URL du pont OpenCode (cloudflared), ex. https://…workers.dev
OPENCODE_BRIDGE_TOKEN → jeton du pont
OPENCODE_MODEL        → modèle free exécuté côté client (défaut deepseek-v4.1-flash-free)
DEEPSEEK_API_KEY      → clé OpenCode Zen (provider deepseek)
DEEPSEEK_BASE_URL     → (optionnel) défaut OpenCode Zen
DEEPSEEK_MODEL        → défaut deepseek-v4.1-flash
CLOUDFLARE_ACCOUNT_ID → compte Cloudflare Workers AI
CLOUDFLARE_API_TOKEN  → token Workers AI
LLM_FALLBACK_ENABLED  → true pour activer la cascade bridge→deepseek→cloudflare
```

### Encore Azure (migration en attente)
```
AZURE_OPENAI_ENDPOINT             → embeddings RAG (rag.ts) + chat legacy ai-chat
AZURE_OPENAI_API_KEY              → idem
AZURE_OPENAI_EMBEDDING_DEPLOYMENT → text-embedding-3-*
AZURE_OPENAI_EMBEDDING_DIMENSIONS → 1536
AZURE_SPEECH_KEY                  → TTS Neural (text-to-speech)
```
> `transcribe-audio` (STT) utilise aussi `AZURE_OPENAI_*` (`gpt-4o-transcribe`).

### IoT
```
MQTT_USERNAME / MQTT_PASSWORD     → broker EMQX Cloud Serverless (voir AGENTS.md)
SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY → Worker MQTT5
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

## Flutter → Edge Function

Le chemin principal est **`agent-orchestrator`** (flux SSE, cf. `lib/services/agent_service.dart`).
La fonction **`ai-chat`** reste un chemin **legacy** (réponse JSON simple, encore Azure) :

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Future<String> askAricieLegacy(String userMessage) async {
  final session = supabase.auth.currentSession;

  final response = await supabase.functions.invoke(
    'ai-chat', // legacy — le chat réel passe par agent-orchestrator (SSE)
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
        {'role': 'user', 'content': userMessage},
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

## Sortie JSON structurée pour commandes IoT (prompt legacy ai-chat)

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

## Outils LLM (agent-orchestrator, LLM tools)

```json
[
  { "name": "get_subscription_info",     "params": {} },
  { "name": "get_my_appliances",         "params": {} },
  { "name": "turn_on_appliance",         "params": { "appliance_name": "string", "confirmed": "boolean (optionnel)" } },
  { "name": "turn_off_appliance",        "params": { "appliance_name": "string", "confirmed": "boolean (optionnel)" } },
  { "name": "get_realtime_consumption",  "params": { "appliance_name": "string" } },
  { "name": "get_device_status",         "params": { "appliance_name": "string" } },
  { "name": "get_total_consumption",     "params": { "period": "string" } },
  { "name": "get_live_consumption",      "params": { "appliance_name": "string" } },
  { "name": "get_energy_history",       "params": { "appliance_name": "string", "period": "day|week|month|year" } },
  { "name": "push_tip",                  "params": { "title": "string", "body": "string", "severity": "info|warning" } }
]
```

### Chaîne LLM & fallback (v2)
`llm.ts` construit une cascade **bridge (OpenCode) → deepseek (OpenCode Zen) → cloudflare (Workers AI)**.
Chaque provider absent/échoué (réseau, timeout, 5xx) bascule sur le suivant. `LLM_FALLBACK_ENABLED=true`
active la cascade complète ; sinon seul le premier provider configuré est appelé.
Azure n'est plus dans cette chaîne (chat/tool-calling).

## Voice Mode Architecture — encore Azure (migration en attente)

```
Flutter Voice Mode
  ┌─────────────────────────────────────────────┐
  │ 1. Appuie sur le micro → record audio (WAV) │
  │ 2. POST /functions/v1/transcribe-audio      │
  │ 3. Azure gpt-4o-transcribe → texte          │
  │ 4. POST /functions/v1/agent-orchestrator    │
  │    (chat / tool calling, SSE)               │
  │ 5. Réponse texte → POST /functions/v1/      │
  │    text-to-speech                           │
  │ 6. Azure Neural TTS → audio MP3            │
  │ 7. Lecture audio via audioplayers           │
  │ 8. Auto-relance écoute (boucle vocale)      │
  └─────────────────────────────────────────────┘

Edge Functions:
  • transcribe-audio     : audio → gpt-4o-transcribe → texte (Azure)
  • text-to-speech       : texte → Azure Neural TTS → audio MP3 (Azure)
  • agent-orchestrator   : message + tools → LLM (OpenCode→DeepSeek→Cloudflare) → SSE
  • ai-chat              : messages → Azure LLM → réponse (legacy)
```

## Testing requis

1. User A → son appareil → autorisé
2. User A → appareil de User B → bloqué
3. "Éteins le chauffe-eau" → device_commands pending
4. Worker MQTT → commande sent
5. Commande dupliquée → pas de double publication
6. RAG User A → jamais document User B
7. Voice → STT → agent → SSE → TTS
8. Provider LLM indisponible → bascule sur le suivant / erreur UI propre

## Évolution future

- Migration hors Azure : embeddings RAG → provider non-Microsoft ; STT/TTS → provider non-Microsoft
- **Worker MQTT persistant** si le broker ne supporte pas HTTP API
- **Dashboard admin** pour supervision des logs agent
- **Feedback loop** : good/bad sur réponses agent
- **Voix basse latence** (WebRTC) hors Azure
