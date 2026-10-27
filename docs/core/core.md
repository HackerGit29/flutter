# Core Module

The core module contains application-wide utilities, security, and dependency injection.

## Security
- `BoxCrypto`: Handles challenge-response handshakes for box pairing using asymmetric signing (Ed25519).
- `TokenManager`: Manages JWT access and refresh tokens using secure storage.
- `RateLimiter`: Prevents API abuse for sync and admin operations.
- `SECURITY.md`: Authoritative security standards (OMT_2024_v2) for the project.

## Supabase Edge Functions
Edge Functions Deno/TypeScript pour l'agent IA, le contrôle IoT et le pipeline énergie.

### agent-orchestrator
L'orchestrateur central de l'agent conversationnel Aricie.

| Fichier | Rôle |
|---|---|
| `index.ts` | Entry point : auth JWT → LLM (`llm.ts`) → tool calling → SSE |
| `auth.ts` | Extraction `user_id` depuis le JWT Supabase (`auth.getUser()`) |
| `tools.ts` | Définition des 5 tools métier + system prompt |
| `llm.ts` | Chaîne LLM multi-provider : OpenCode bridge → DeepSeek → Cloudflare Workers AI |
| `azure_openai.ts` | Legacy : client Azure OpenAI (chat), **non importé** par l'orchestrateur |
| `policy.ts` | Résolution des noms métier → IDs + vérification ownership |
| `actions.ts` | Insertion `device_commands`, lecture `energy_data`, etc. |
| `audit.ts` | Journalisation dans `agent_audit_logs` |
| `rag.ts` | Embeddings + RAG vectoriel scope par `owner_id` (embeddings encore Azure) |
| `stream.ts` | Utilitaires SSE (headers, write events) |
| `types.ts` | Types TypeScript partagés |

### energy-aggregator
ETL quotidien : lit `realtime_power` (table du worker MQTT5) et upsert dans `energy_data` pour les stats historique. Un seul fichier : `index.ts`.

### Secrets requis

#### Dashboard Supabase — chaîne LLM chat (`llm.ts`)
```
OPENCODE_BRIDGE_URL / OPENCODE_BRIDGE_TOKEN / OPENCODE_MODEL
DEEPSEEK_API_KEY / DEEPSEEK_MODEL
CLOUDFLARE_ACCOUNT_ID / CLOUDFLARE_API_TOKEN
LLM_FALLBACK_ENABLED=true
```

#### Dashboard Supabase — encore Azure (RAG embeddings + voix ; migration en attente)
```
AZURE_OPENAI_ENDPOINT
AZURE_OPENAI_API_KEY
AZURE_OPENAI_EMBEDDING_DEPLOYMENT → text-embedding-3-*
AZURE_SPEECH_KEY                 → TTS Neural
```

#### Worker MQTT 5 fichier `.env`
```
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
MQTT_USERNAME=
MQTT_PASSWORD=
```

> Les secrets Supabase sont configurés dans le dashboard. Les credentials MQTT (EMQX Cloud Serverless) sont dans le `.env` du worker Node.js `workers/mqtt5-worker/` (ou posés en secrets du Worker Cloudflare).

> Les secrets ne sont jamais accessibles côté client Flutter.

## Migrations SQL

### agent_tables (`20260623000001_agent_tables.sql`)
| Table | Description |
|---|---|
| `device_commands` | File d'attente des commandes appareil (pending → sent → acknowledged/failed) |
| `agent_audit_logs` | Journal immuable des décisions de l'agent |
| `chat_embeddings` | Vecteurs RAG scope par `owner_id` (pgvector) |

### admin_provisioning (`20260626000003_admin_provisioning.sql`)
- Nettoie les lignes `uid_hardware = ''` dans `boxes`
- Ajoute `CHECK (length(uid_hardware) > 8)` sur `boxes.uid_hardware`
- Ajoute `DELETE` policy admin sur `appliances` (permet à l'admin de supprimer des appliances orphelines)

### Fonctions RPC
- `match_user_embeddings(query_embedding, requester_id, match_count)` : Recherche vectorielle scopée par utilisateur
- `get_user_appliances_context(requester_id)` : Contexte opérationnel de l'utilisateur

## Dependency Injection
- `injection_container.dart`: Service locator using `get_it` for singleton management. Registers all datasources, repositories, and use-cases (Auth, Box, Appliance, Energy, License, Sync, Admin).

## Constants & Errors
- `constants.dart`: App-wide configuration (SUPABASE_URL, rate limits, MQTT broker).
- `failures.dart`: Sealed class hierarchy for typed error handling (Auth, Box, Appliance, License, Sync, Admin).
