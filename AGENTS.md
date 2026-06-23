# AGENTS.md — aricie

## Quick start

```bash
fvm flutter pub get
fvm flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
fvm flutter test
fvm flutter analyze
fvm flutter build apk --obfuscate --split-debug-info=build/obfuscation/
```

> `SUPABASE_URL` and `SUPABASE_ANON_KEY` are required via `--dart-define`. Obtain from Supabase dashboard (Project > Settings > API).

## Stack

| Layer | Technology |
|-------|-----------|
| App | Flutter 3.29.0 (FVM-managed, see `.fvmrc`) |
| State | Riverpod (preferred) + Provider (theme only) |
| Backend | Supabase (auth, realtime streams, PostgreSQL, Edge Functions) |
| AI Agent | Supabase Edge Functions + Azure OpenAI GPT-4o (tool calling + streaming) |
| MQTT | MQTT 5.0 via flespi broker, `mqtt5_client`, Node.js worker (mqtt.js v5) |
| RAG | pgvector (chat_embeddings, owner_id scopé) |
| IoT | MQTT 5.0 via `mqtt5_client` (TCP TLS `mqtt.flespi.io:8883`, WSS `mqtt.flespi.io:443`) |
| Voice | `speech_to_text` (STT) + `flutter_tts` (TTS) |
| Design | Soft Wellness Minimalism — seed `#4A6572`, DM Sans, pastel palette |
| Architecture | Clean Architecture (`core/` → `data/` → `domain/` → `presentation/`) |

## Project conventions

- **Package**: `aricie` (`pubspec.yaml` name)
- **Language**: Dart 3 with strict typing
- **User-facing strings**: All in French
- **Navigation**: `Navigator.push` / `pushReplacement` (no GoRouter)
- **Error handling**: Sealed `Failure` hierarchy with `Either<Failure, T>` via `dartz`
- **DI**: `get_it` service locator (`lib/core/di/injection_container.dart`)
- **Dependency override**: `dependency_overrides.web: 1.1.1`
- **Static analysis**: Checked via `fvm flutter analyze`; MQTT-related errors on web are expected (uses conditionals)

## Architecture layers

```
lib/
  main.dart                  ← App init (Supabase, notifications, splash → auth)
  core/                      ← Utilities, errors, DI, security
    constants.dart           ← Env-based config (--dart-define)
    errors/failures.dart     ← Sealed Failure hierarchy
    di/injection_container.dart  ← get_it (25+ registrations)
    security/                ← TokenManager, DeviceCrypto, RateLimiter
  data/                      ← Datasources + repository implementations
    datasources/             ← SupabaseAuth, SupabaseBox, SupabaseAppliance, SupabaseEnergy, SupabaseLicense, SupabaseSync, SupabaseAdmin, Local
    repositories/            ← AuthRepositoryImpl, BoxRepositoryImpl, ApplianceRepositoryImpl, EnergyRepositoryImpl, LicenseRepositoryImpl, SyncRepositoryImpl, AdminRepositoryImpl
  domain/                    ← Entities, repository interfaces, use-cases
    entities/                ← User, Box, Appliance, EnergyData, Subscription, License, SyncLog, AdminAction
    repositories/            ← Abstract interfaces (7)
    usecases/                ← 26+ use-cases across auth, boxes, appliances, energy, license, sync, admin
  presentation/              ← Screens, widgets, theme
    screens/                 ← Auth, Home (Dashboard/Stats/Devices/Settings), Admin, Chatbot
    widgets/                 ← PremiumGateWidget, MetricChart, ChatBubble, ChatInput, MessageBubble
    theme/                   ← app_theme.dart (light/dark, Material 3)
  services/                  ← External service integrations
    agent_service.dart       ← SSE client → Edge Function agent-orchestrator
    voice_service.dart       ← STT (speech_to_text) + TTS (flutter_tts)
    mqtt_service.dart        ← MQTT 5.0 (flespi broker, telemetry/status only)
    auth_service.dart        ← Auth wrapper
    notification_service.dart← Notifications
    mqtt/
      mqtt5_client_interface.dart ← Interface abstraite MQTT 5
      mqtt5_native.dart       ← Client natif TCP TLS
      mqtt5_web.dart          ← Client web WSS

supabase/
  functions/
    agent-orchestrator/      ← Edge Function : Azure OpenAI + tool calling + SSE

workers/
  mqtt5-worker/              ← Node.js worker MQTT 5 (mqtt.js v5)
    package.json
    index.js                 ← Claim pending → publish cmd → listen ACK
  migrations/
    20260621133535_init_schema.sql
    20260623000001_agent_tables.sql  ← device_commands, agent_audit_logs, chat_embeddings
```

## Key entrypoints

| File | Role |
|------|------|
| `lib/main.dart` | App initialization: Supabase, notifications, splash → auth flow |
| `lib/services/mqtt_service.dart` | IoT messaging (telemetry stream, control commands) |
| `lib/services/agent_service.dart` | SSE client for agent-orchestrator Edge Function |
| `lib/services/voice_service.dart` | STT (speech to text) + TTS (text to speech) |
| `lib/services/auth_service.dart` | High-level auth wrapper (uses secure storage) |
| `lib/services/notification_service.dart` | Local and push notifications |
| `lib/theme/app_theme.dart` | Light/dark theme (Material 3, seed `#4A6572`) |
| `lib/screens/home_screen.dart` | Main dashboard (tabs: Dashboard, Stats, Devices, Settings) |
| `lib/screens/chatbot/chatbot_screen.dart` | Chat UI with SSE streaming + voice mode toggle |
| `lib/core/constants.dart` | Environment-based configuration |

## AI Agent Architecture

```
Flutter Chat / Voice
  → AgentService (SSE)
    → POST /functions/v1/agent-orchestrator (JWT + message)
      → auth.ts : user_id extrait du JWT (ignoré du body)
      → context opérationnel (appliances scope user)
      → RAG pgvector (owner_id = requester_id)
      → Azure OpenAI GPT-4o tool calling
      → Policy Engine (ownership + rate limit)
      → device_commands (file d'attente)
      → audit log
      → SSE streaming typé
    → Worker MQTT (webhook)
      → pending → MQTT publish → sent/failed
```

### Principes de sécurité
- **`user_id`** : uniquement depuis `auth.getUser()` JWT, jamais depuis le body
- **LLM** : ne manipule que des noms métier (`chauffe-eau`), pas d'IDs techniques
- **Policy Engine** : toute action vérifiée (ownership + rate limit) avant exécution
- **device_commands** : file d'attente, l'agent ne publie jamais MQTT directement
- **RAG** : tous les filtres vectoriels incluent `WHERE owner_id = requester_id`

## Database (Supabase)

### Tables existantes
`users`, `boxes`, `appliances`, `energy_data`, `subscriptions`, `licenses`, `sync_logs`, `admin_actions`

### Nouvelles tables (agent)
| Table | Description |
|---|---|
| `device_commands` | File d'attente des commandes appareil (pending → sent → failed) |
| `agent_audit_logs` | Journal immuable des décisions de l'agent |
| `chat_embeddings` | Vecteurs RAG pgvector scope par `owner_id` |

All tables use RLS. Full schema in `docs/supabase/init_db.sql` and `supabase/migrations/`.

## 2026 project evolution (in progress)

- **AI Agent v2**: Flowise → Supabase Edge Functions + Azure OpenAI GPT-4o
- **Voice mode**: STT/TTS intégré au chatbot avec toggle dans l'AppBar
- **Live streaming**: SSE streaming typé (token/tool_pending/tool_result/done)
- **Device control from chat**: "Éteins le chauffe-eau" → Policy Engine → MQTT
- **RAG vectoriel**: pgvector scope par utilisateur
- **Worker MQTT**: Découplage commande via device_commands + webhook

## Design system (2026)

- Color accent: `rgb(121, 207, 244)` for system diagrams
- Soft Wellness Minimalism: pastels, rounded corners (12px+), DM Sans, generous padding
- Target screen: 375×812px (iPhone)

## Commands cheat sheet

```bash
fvm flutter clean && fvm flutter pub get   # Reset dependencies
fvm dart run flutter_launcher_icons        # Regenerate app icons
fvm flutter build apk --obfuscate --split-debug-info=build/obfuscation/  # Release build
```

## Testing

- `test/domain/entities/user_test.dart` — User entity unit tests (passing)
- `test/widget_test.dart` — placeholder, needs rewrite
- BDD scenarios: `test_driver/features/*.feature` (Gherkin)
- Step definitions: `test_driver/steps/*.dart`

## Branch naming

`<type>/<short-description>` — types: `feat/`, `fix/`, `refactor/`, `docs/`, `test/`, `chore/`, `security/`

## Commit convention

[Conventional Commits](https://www.conventionalcommits.org/): `<type>(<scope>): <description>`
- Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `style`, `perf`, `security`
- Scopes: `auth`, `devices`, `license`, `admin`, `sync`, `core`, `data`, `domain`, `ui`, `mqtt`, `supabase`, `agent`, `rag`, `voice`, `deps`

## Versioning

Semantic Versioning 2.0.0. Canonical version in `pubspec.yaml`. See `VERSION.md`.

## Gotchas

- MQTT on web uses stub client (`mqtt/mqtt_web.dart`) — features limited
- Supabase URL/key required via `--dart-define` at compile time
- `mqtt_client` import from `src/typed_buffer.dart` directly (non-standard pattern)
- `dependency_overrides.web: 1.1.1` pinned to avoid breaking changes
- Azure OpenAI secrets must be set in Supabase dashboard (Edge Functions secrets)
- `WEBHOOK_SECRET` required for mqtt-worker webhook security
- **Never commit secrets** — use `--dart-define` only
