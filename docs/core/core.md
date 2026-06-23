# Core Module

The core module contains application-wide utilities, security, and dependency injection.

## Security
- `BoxCrypto`: Handles challenge-response handshakes for box pairing using asymmetric signing (Ed25519).
- `TokenManager`: Manages JWT access and refresh tokens using secure storage.
- `RateLimiter`: Prevents API abuse for sync and admin operations.
- `SECURITY.md`: Authoritative security standards (OMT_2024_v2) for the project.

## Supabase Edge Functions
Deux Edge Functions Deno/TypeScript pour l'agent IA et le contrôle IoT.

### agent-orchestrator
L'orchestrateur central de l'agent conversationnel Aricie.

| Fichier | Rôle |
|---|---|
| `index.ts` | Entry point : auth JWT → Azure OpenAI → tool calling → SSE |
| `auth.ts` | Extraction `user_id` depuis le JWT Supabase (`auth.getUser()`) |
| `tools.ts` | Définition des 5 tools métier + system prompt |
| `azure_openai.ts` | Client Azure OpenAI GPT-4o (tool calling + streaming) |
| `policy.ts` | Résolution des noms métier → IDs + vérification ownership |
| `actions.ts` | Insertion `device_commands`, lecture `energy_data`, etc. |
| `audit.ts` | Journalisation dans `agent_audit_logs` |
| `rag.ts` | Embeddings + RAG vectoriel scope par `owner_id` |
| `stream.ts` | Utilitaires SSE (headers, write events) |
| `types.ts` | Types TypeScript partagés |

### Secrets requis

#### Dashboard Supabase (Edge Function)
```
AZURE_OPENAI_ENDPOINT
AZURE_OPENAI_API_KEY
AZURE_OPENAI_DEPLOYMENT           → gpt-4o
AZURE_OPENAI_API_VERSION          → 2024-10-21
AZURE_OPENAI_EMBEDDING_DEPLOYMENT → text-embedding-3-small
```

#### Worker MQTT 5 fichier `.env`
```
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
FLESPI_MQTT_HOST=mqtt.flespi.io
FLESPI_MQTT_TCP_PORT=8883
FLESPI_MQTT_WORKER_TOKEN=
```

> Les secrets Supabase sont configurés dans le dashboard. Les variables flespi sont dans le `.env` du worker Node.js `workers/mqtt5-worker/`.

> Les secrets ne sont jamais accessibles côté client Flutter.

## Migration SQL (agent_tables)
Référence : `supabase/migrations/20260623000001_agent_tables.sql`

| Table | Description |
|---|---|
| `device_commands` | File d'attente des commandes appareil (pending → sent → acknowledged/failed) |
| `agent_audit_logs` | Journal immuable des décisions de l'agent |
| `chat_embeddings` | Vecteurs RAG scope par `owner_id` (pgvector) |

### Fonctions RPC
- `match_user_embeddings(query_embedding, requester_id, match_count)` : Recherche vectorielle scopée par utilisateur
- `get_user_appliances_context(requester_id)` : Contexte opérationnel de l'utilisateur

## Dependency Injection
- `injection_container.dart`: Service locator using `get_it` for singleton management. Registers all datasources, repositories, and use-cases (Auth, Box, Appliance, Energy, License, Sync, Admin).

## Constants & Errors
- `constants.dart`: App-wide configuration (SUPABASE_URL, rate limits, MQTT broker).
- `failures.dart`: Sealed class hierarchy for typed error handling (Auth, Box, Appliance, License, Sync, Admin).
