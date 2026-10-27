# AGENTS.md — aricie

## Quick start

```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
flutter test
flutter analyze
flutter build apk --obfuscate --split-debug-info=build/obfuscation/
```

> `SUPABASE_URL` and `SUPABASE_ANON_KEY` are required via `--dart-define`. Obtain from Supabase dashboard (Project > Settings > API).

## Stack

| Layer        | Technology                                                                               |
| ------------ | ---------------------------------------------------------------------------------------- |
| App          | Flutter (latest stable)                                               |
| State        | Riverpod (preferred) + Provider (theme only)                                             |
| Backend      | Supabase (auth, realtime streams, PostgreSQL, Edge Functions)                            |
| AI Agent     | Supabase Edge Functions + Azure Phi-4-mini-instruct (chat) / Azure OpenAI (tool calling) |
| MQTT         | MQTT 5.0 via EMQX Cloud Serverless (Europe, déploiement `dev`), `mqtt5_client`, Node.js worker (mqtt.js v5) |
| RAG          | pgvector (chat_embeddings, owner_id scopé)                                               |
| IoT          | MQTT 5.0 via `mqtt5_client` (TCP TLS `r1aa3902.ala.eu-central-1.emqxsl.com:8883`, WSS `:8084/mqtt`) |
| Voice        | `speech_to_text` (STT) + `flutter_tts` (TTS) ✅ Migré vers Azure gpt-4o-transcribe (STT) + Azure Neural TTS (TTS) via Edge Functions |
| Design       | Soft Wellness Minimalism — seed `#4A6572`, DM Sans, pastel palette                       |
| Architecture | Clean Architecture (`core/` → `data/` → `domain/` → `presentation/`)                     |

## Project conventions

- **Package**: `aricie` (`pubspec.yaml` name)
- **Language**: Dart 3 with strict typing
- **User-facing strings**: All in French
- **Navigation**: `Navigator.push` / `pushReplacement` (no GoRouter)
- **Error handling**: Sealed `Failure` hierarchy with `Either<Failure, T>` via `dartz`
- **DI**: `get_it` service locator (`lib/core/di/injection_container.dart`)
- **Dependency override**: `dependency_overrides.web: 1.1.1`
- **Static analysis**: Checked via `flutter analyze`; MQTT-related errors on web are expected (uses conditionals)
- **Logging**: JSON export to GCS for debugging and analysis

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
    widgets/                 ← PremiumGateWidget, MetricChart, LiveConsumptionIndicator, ChatBubble, ChatInput, MessageBubble
    theme/                   ← app_theme.dart (light/dark, Material 3)
  services/                  ← External service integrations
    agent_service.dart       ← SSE client → Edge Function agent-orchestrator
    voice_service.dart       ← STT (speech_to_text) + TTS (flutter_tts)
    mqtt_service.dart        ← MQTT 5.0 (EMQX broker, telemetry/status only)
    auth_service.dart        ← Auth wrapper
    notification_service.dart← Notifications
    mqtt/
      mqtt5_client_interface.dart ← Interface abstraite MQTT 5
      mqtt5_native.dart       ← Client natif TCP TLS
      mqtt5_web.dart          ← Client web WSS

  supabase/
  functions/
    ai-chat/                 ← Edge Function : Chat simple Phi-4-mini-instruct
    agent-orchestrator/      ← Edge Function : Azure OpenAI + tool calling + SSE
    energy-aggregator/       ← Edge Function : ETL realtime_power → energy_data
    admin-api/               ← Edge Function : backoffice web (KPI, users, boxes, RBAC)
  migrations/
    20260621133535_init_schema.sql
    20260623000001_agent_tables.sql  ← device_commands, agent_audit_logs, chat_embeddings
    20260626000003_admin_provisioning.sql  ← CHECK constraint, DELETE policy admin
    20260627000005_tips_generator_cron.sql  ← Cron hebdo tips énergie
    20260627000006_boxes_user_id_nullable.sql  ← ALTER boxes.user_id DROP NOT NULL
    20260627000007_boxes_uid_hardware_check.sql  ← CHECK length(uid_hardware) > 8

workers/
  mqtt5-worker/              ← Node.js worker MQTT 5 (mqtt.js v5)
    package.json
    index.js                 ← Claim pending → publish cmd → listen ACK + subscribe telemetry
    README.md                ← Build/deploy process, troubleshooting
  test/box/
    box_esp32.py             ← Simulateur ESP32 Python (télémétrie, ACK, 3 relays)
    requirements.txt         ← paho-mqtt
    README.md                ← Usage et workflow de test
```

## Key entrypoints

| File                                      | Role                                                            |
| ----------------------------------------- | --------------------------------------------------------------- |
| `lib/main.dart`                           | App initialization: Supabase, notifications, splash → auth flow |
| `lib/core/constants.dart`                 | Environment-based configuration (`--dart-define`)               |
| `supabase/functions/ai-chat/index.ts`     | Edge Function Phi-4-mini-instruct (chat simple)                 |
| `supabase/functions/agent-orchestrator/`  | Edge Function avancée (tool calling + SSE + RAG)                |
| `supabase/functions/transcribe-audio/index.ts` | Edge Function : audio → gpt-4o-transcribe → texte          |
| `supabase/functions/text-to-speech/index.ts`   | Edge Function : texte → Azure Neural TTS → audio MP3        |
| `supabase/functions/energy-aggregator/index.ts`| Edge Function : ETL realtime_power → energy_data quotidien  |
| `supabase/functions/admin-api/index.ts` | Edge Function : backoffice web (KPI, users, boxes, RBAC admin) |
| `lib/services/mqtt_service.dart`          | IoT messaging (telemetry stream, control commands)              |
| `lib/services/agent_service.dart`         | SSE client for agent-orchestrator Edge Function                 |
| `lib/services/voice_service.dart`         | STT (Azure transcribe) + TTS (Azure Neural TTS)                 |
| `lib/services/auth_service.dart`          | High-level auth wrapper (uses secure storage)                   |
| `lib/services/notification_service.dart`  | Local and push notifications                                    |
| `lib/theme/app_theme.dart`                | Light/dark theme (Material 3, seed `#4A6572`)                   |
| `lib/screens/home_screen.dart`            | Main dashboard (tabs: Dashboard, Stats, Devices, Settings)      |
| `lib/screens/chatbot/chatbot_screen.dart` | Chat UI with SSE streaming + voice mode toggle                  |
| `lib/widgets/live_consumption_indicator.dart` | Widget conso live temps réel (stream MQTT)                  |

## AI Agent Architecture

```
Flutter Chat / Voice
  → AgentService (SSE)
    → POST /functions/v1/agent-orchestrator (JWT + message)
      → auth.ts : user_id extrait du JWT (ignoré du body)
      → context opérationnel (appliances + subscription scope user)
      → RAG pgvector (owner_id = requester_id)
      → LLM : bridge OpenCode (free) → DeepSeek v4.1-flash → Cloudflare Workers AI (tool calling)
      → Policy Engine (ownership + rate limit + criticalité haute → confirmation modale)
      → device_commands (file d'attente)
      → audit log
      → SSE streaming typé
    → Worker MQTT (webhook)
      → pending → MQTT publish → sent/failed
```

**Actions critiques** : backend demande confirmation modale via `tool_pending { requires_confirmation: true }`. Flutter envoie `confirmed_tool_call` structuré (contourne le LLM) pour exécution directe, avec `confirmed: true` dans les arguments pour éviter la boucle infinie.

**Tools** : `get_subscription_info`, `get_my_appliances`, `turn_on_appliance`, `turn_off_appliance`, `get_realtime_consumption`, `get_device_status`, `get_total_consumption`, `get_live_consumption`, `get_energy_history`, `push_tip`

**Providers LLM** (`llm.ts`) : chaîne ordonnée `bridge` (OpenCode local, gratuit) → `deepseek` (OpenCode Zen, LLM de base `deepseek-v4.1-flash`) → `cloudflare` (Workers AI, `@cf/deepseek-ai/deepseek-v4.1-flash-1017`). Toute panne (réseau, timeout, 5xx) bascule sur le suivant. Azure OpenAI retiré (abonnement terminé).

### OpenCode bridge (LLM free)

Les modèles `*-free` d'OpenCode Zen refusent les appels serveur (`403 FreeTierError: can only be used from within OpenCode`). `workers/opencode-bridge/` fait exécuter la requête par le **client OpenCode de la machine de dev** (`opencode serve` sur `:4096`) et l'expose en `POST /chat/completions` OpenAI sur `:4097`, publié par `cloudflared`.

- `bash workers/opencode-bridge/start.sh` → pont + tunnel + secrets Supabase (`OPENCODE_BRIDGE_URL`, `OPENCODE_BRIDGE_TOKEN`, `OPENCODE_MODEL`)
- Tool calling : les définitions sont passées dans le prompt, le pont reconvertit le JSON en `tool_calls` OpenAI
- Contrepartie : le chat ne répond que si la machine est allumée ; `supabase secrets unset OPENCODE_BRIDGE_URL` pour revenir à DeepSeek/Azure
- Doc : `workers/opencode-bridge/README.md`

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

| Table              | Description                                                     |
| ------------------ | --------------------------------------------------------------- |
| `device_commands`  | File d'attente des commandes appareil (pending → sent → failed) |
| `agent_audit_logs` | Journal immuable des décisions de l'agent                       |
| `chat_embeddings`  | Vecteurs RAG pgvector scope par `owner_id`                      |

All tables use RLS. Admin bypass via `private.is_admin()` (SECURITY DEFINER querying `public.users.role`). Full schema in `docs/supabase/init_db.sql` and `supabase/migrations/`.

## 2026 project evolution (in progress)

- **AI Agent v2**: Flowise → Supabase Edge Functions + Phi-4-mini-instruct (chat) / Azure OpenAI (tool calling) ✅
- **Voice mode**: STT/TTS intégré au chatbot avec toggle dans l'AppBar ✅
- **Live streaming**: SSE streaming typé (token/tool_pending/tool_result/done) ✅
- **Device control from chat**: "Éteins le chauffe-eau" → Policy Engine → MQTT ✅
- **RAG vectoriel**: pgvector scope par utilisateur ✅
- **Worker MQTT**: Découplage commande via device_commands + webhook ✅
- **Admin provisioning**: Création boîtiers/appareils depuis dashboard admin ✅
- **Pipeline stats**: Edge Function energy-aggregator + LiveConsumptionIndicator ✅
- **Refonte UI appareils**: DevicesScreen lecture seule, toggle via device_commands ✅
- **Nettoyage secrets**: supabaseServiceRoleKey, flespiWorkerToken retirés de constants.dart ✅
- **Phi-4-mini-instruct**: Déployé sur Azure Foundry (chat et agent) ✅
- **MQTT App singleton**: MqttService enregistré via get_it, paramètre `force` dans initialize, StreamController _connectionStateController non recréé pour préserver les abonnements ✅
- **Boîtiers admin nullables**: ALTER boxes.user_id DROP NOT NULL, dropdown admin corrigé (initialValue → value) ✅
- **Simulateur ESP32 Python**: workers/test/box/box_esp32.py — télémetrie 5s, ACK, 3 relays ✅
- **Worker souscrit télémétrie**: souscrit à aricie/v1/boxes/+/telemetry en plus des ACK ✅
- **FLESPI_DEFAULT_BOX_UID**: compile-time override pour fallback MQTT sans appliances en BDD ✅
- **Fix UI Settings**: padding bottom kBottomNavigationBarHeight pour éviter débordement navbar ✅
- **Tools IA subscription + appliances**: `get_subscription_info`, `get_my_appliances` ajoutés au LLM ✅
- **Confirmation structurée**: `confirmed_tool_call` contourne le LLM, envoi direct au backend ✅
- **Bug fix labels toggles**: `_toolLabelToFrench` corrigé pour les vrais noms de tools (`turn_on_appliance`, etc.) ✅
- **IndexedStack tabs**: remplacement `Stack` → `IndexedStack` dans home_screen pour préserver les souscriptions entre tabs ✅
- **Bouton Ajouter admin-only**: vérification `isAdmin` dans settings_screen ✅
- **Toggle optimiste**: feedback immédiat + loading spinner + revert sur échec dans devices_screen ✅
- **GPT-4o**: En attente d'augmentation de quota
- **Fix RPC sum_total_consumption**: TOO_MANY_ROWS avec >1 appareil — passage en sous-requêtes scalaires ✅
- **Fix boucle confirmation**: `confirmed: true` manquant dans les args Flutter ✅
- **UX Chatbot clean**: suppression de l'affichage des appels de fonctions intermédiaires ✅
- **Realtime energy_data + device_commands**: activation publication Supabase Realtime ✅
- **DeepSeek fallback LLM**: bascule automatique si Azure OpenAI est indisponible ✅

## Design system (2026)

- Color accent: `rgb(121, 207, 244)` for system diagrams
- Soft Wellness Minimalism: pastels, rounded corners (12px+), DM Sans, generous padding
- Target screen: 375×812px (iPhone)

## Commands cheat sheet

```bash
flutter clean && flutter pub get   # Reset dependencies
dart run flutter_launcher_icons        # Regenerate app icons
flutter build apk --obfuscate --split-debug-info=build/obfuscation/  # Release build
```

## MQTT — Architecture des credentials

Broker en production : **EMQX Cloud Serverless** (MQTT 5), déploiement `dev`,
région Europe → `r1aa3902.ala.eu-central-1.emqxsl.com`. Serverless n'expose que
**8883 (MQTT over TLS)** et **8084 (WSS, chemin `/mqtt`)** : pas de port en clair.
Les noms `FLESPI_*` restent lus en repli dans le code, mais l'ancien broker est
abandonné (tokens révoqués, cf. issue #37).

| Composant | Variables | Permissions | Usage |
|-----------|-----------|-------------|-------|
| Worker (`mqtt5-worker`) | `MQTT_USERNAME` / `MQTT_PASSWORD` | PUBLISH `.../relays/+/cmd`, SUBSCRIBE `.../ack` + `.../telemetry` | Envoi commandes aux boitiers |
| App Flutter | `MQTT_USERNAME` / `MQTT_PASSWORD` (`--dart-define`) | SUBSCRIBE telemetry/status | Recuperer donnees capteurs en temps reel |
| Simulateur / ESP32 | `MQTT_HOST` / `MQTT_PORT` / `MQTT_USERNAME` / `MQTT_PASSWORD` | PUBLISH telemetry/status/ack | Tests e2e |

Legacy Flespi : un seul token sert de username **et** de password
(`FLESPI_MQTT_WORKER_TOKEN` / `FLESPI_MQTT_APP_TOKEN`).

### Flux de commandes

```
Flutter → Edge Function (agent-orchestrator) → device_commands (BDD)
  → Worker MQTT → publie sur MQTT → Boitier
  → Boitier repond ACK → Worker met a jour device_commands
```

**L'app Flutter ne publie JAMAIS sur MQTT.** Toutes les commandes passent par la file `device_commands`.

### Connexion MQTT de l'app

- `MqttService` est un singleton enregistré via `get_it` (`sl.registerLazySingleton<MqttService>(() => MqttService())`)
- L'app se connecte au broker avec un `boxUid` (depuis BDD ou `FLESPI_DEFAULT_BOX_UID` en fallback)
- Le `boxUid` est `uid_hardware` de la table `boxes` (recupere via join appliances/boxes)
- `force: true` dans `initialize()` ne recrée PAS `_connectionStateController` — les `StreamBuilder` déjà montés gardent leur abonnement
- En cas de connexion échouée, `_scheduleReconnect()` tente une reconnexion après 5s
- Si pas d'appareils et pas de `FLESPI_DEFAULT_BOX_UID` : connexion MQTT skipée, pas de notification
- Credentials : `AppConstants.mqttHost` / `mqttTcpPort` / `mqttUsername` / `mqttPassword` (dart-define `MQTT_HOST`, `MQTT_TCP_PORT`, `MQTT_USERNAME`, `MQTT_PASSWORD`), avec repli automatique sur les constantes Flespi

## MQTT5 Worker — Build & Deploy

Le worker relaye les commandes IoT (`device_commands` Supabase → boîtiers via MQTT 5).

### Infrastructure (Cloudflare Containers)

| Ressource      | Valeur                                                  | Méthode d'accès                     |
| -------------- | ------------------------------------------------------- | ----------------------------------- |
| Worker         | `aricie-mqtt5-worker`                                   | `wrangler deploy` / `wrangler tail` |
| Container app  | `aricie-mqtt5-worker-mqtt5container`                     | `wrangler deploy`                   |
| Registre       | `registry.cloudflare.com`                               | poussé par `wrangler deploy`        |
| Instance type  | `basic` (1 GiB)                                         | `wrangler.jsonc`                    |

**Règle : les services Azure (Container Apps, ACR, build-vm) ont été supprimés —
l'abonnement a pris fin.** Le build Docker se fait en local (WSL Debian, Docker
disponible) et `wrangler deploy` construit + pousse l'image depuis le
`Dockerfile` du dossier. Aucune commande `az` ne doit être réintroduite.

### Workflow

```
Modifier workers/mqtt5-worker/app.js
  → wsl -d Debian -u root -- bash -c "cd '<repo>/workers/mqtt5-worker' && wrangler deploy"
    → Docker build local → push registry.cloudflare.com → update container app
  → curl /_stop  (un container running ne réapplique pas envVars)
  → curl /health (app_loaded, mqtt_state, missing_env, fatal_errors)
```

### Commandes

```bash
# Build + push + deploy complet
./scripts/deploy-cloudflare.sh

# Deploy seul (image inchangée)
SKIP_BUILD=1 ./scripts/deploy-cloudflare.sh

# Déployer depuis Windows (Docker uniquement dans WSL)
wsl -d Debian -u root -- bash -c "cd '<repo>/workers/mqtt5-worker' && wrangler deploy"

# Secrets (posés sur le Worker, relayés au container par worker.js)
wrangler secret put SUPABASE_URL
wrangler secret put SUPABASE_SERVICE_ROLE_KEY
wrangler secret put MQTT_USERNAME
wrangler secret put MQTT_PASSWORD
```

### Vérification

```bash
curl https://aricie-mqtt5-worker.smitthwillson1213.workers.dev/health
curl https://aricie-mqtt5-worker.smitthwillson1213.workers.dev/diag/supabase
```

`/health` répond toujours 200 ; `status: degraded` = app cassée mais container
vivant. Lecture des champs :

```json
{ "status": "ok", "app_loaded": true, "mqtt_state": "connected",
  "missing_env": [], "fatal_errors": [], "stats": { "acksProcessed": 1 } }
```

- `missing_env` non vide → secrets absents ou posés **vides** (l'API accepte le vide)
- `mqtt_state: closed` + `Bad User Name or Password` → credentials refusés par EMQX (utilisateur supprimé/régénéré dans le dashboard)
- `/diag/supabase` ≠ 200 → URL/clé Supabase invalides

### Documentation

- `workers/mqtt5-worker/README.md` — Architecture détaillée, env vars, troubleshooting
- `docs/services/services.md#mqtt-worker--build--deploy` — Vue d'ensemble infra

## Testing

- `test/domain/entities/user_test.dart` — User entity unit tests (passing)
- `test/widget_test.dart` — placeholder, needs rewrite
- BDD scenarios: `test/*.feature` (Gherkin) compiled to widget tests by `bdd_widget_test`
- Custom steps: `test/step/*.dart` — regenerate with `dart run build_runner build`, run with `flutter test`

## Branch naming

`<type>/<short-description>` — types: `feat/`, `fix/`, `refactor/`, `docs/`, `test/`, `chore/`, `security/`

## Commit convention

[Conventional Commits](https://www.conventionalcommits.org/): `<type>(<scope>): <description>`

- Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `style`, `perf`, `security`
- Scopes: `auth`, `devices`, `license`, `admin`, `sync`, `core`, `data`, `domain`, `ui`, `mqtt`, `supabase`, `agent`, `rag`, `voice`, `deps`

## Versioning

Semantic Versioning 2.0.0. Canonical version in `pubspec.yaml`. See `VERSION.md`.

## Relevant Files

| File                                      | Role                                                            |
| ----------------------------------------- | --------------------------------------------------------------- |
| `lib/screens/devices/devices_screen.dart`     | Refondu (lecture seule, sans FAB/MQTT, catégories dérivées)      |
| `lib/data/datasources/supabase_appliance_datasource.dart` | `toggleAppliance` écrit `device_commands` + `appliances.update` |
| `lib/data/datasources/supabase_admin_datasource.dart` | Nouvelles méthodes `createBox` et `createAppliancesForBox` |
| `lib/domain/usecases/admin/create_box_for_user.dart` | Use-case admin création boîtier |
| `lib/domain/usecases/admin/create_appliances_for_box.dart` | Use-case admin création 3 appliances |
| `lib/domain/usecases/admin/get_available_boxes.dart` | Use-case admin boîtiers disponibles |
| `lib/screens/admin/admin_dashboard_screen.dart` | FAB + dialog création boîtier (onglet Boîtiers) |
| `lib/screens/home_screen.dart` | Initialisation MQTT après chargement appliances, fallback `FLESPI_DEFAULT_BOX_UID`, IndexedStack tabs |
| `lib/screens/settings/settings_screen.dart` | Statut MQTT via singleton, padding bottom navbar fixé, bouton Ajouter admin-only |
| `lib/screens/devices/devices_screen.dart` | Toggle optimiste avec loading spinner + revert sur échec |
| `lib/services/mqtt_service.dart` | Singleton via get_it, `force` paramètre, `sendDebugControlCommand` supprimé |
| `lib/services/agent_service.dart` | SSE client, paramètre `confirmedToolCall` pour confirmation structurée |
| `supabase/functions/agent-orchestrator/tools.ts` | 10 tools LLM dont `get_subscription_info`, `get_my_appliances` |
| `supabase/functions/agent-orchestrator/index.ts` | Handle confirmed_tool_call, handlers pour subscription + appliances |
| `lib/core/di/injection_container.dart` | `sl.registerLazySingleton<MqttService>` |
| `lib/core/constants.dart` | `supabaseServiceRoleKey` et `flespiWorkerToken` supprimés, `flespiDefaultBoxUid` ajouté |
| `lib/providers/subscription_provider.dart` | `reset()`, `loadForUser(String userId)` — pas de SharedPreferences |
| `lib/domain/usecases/license/get_user_subscription.dart` | `callForUser(String userId)` pour requête scope |
| `lib/data/repositories/license_repository_impl.dart` | `getUserSubscriptionForUser` implémenté |
| `workers/test/box/box_esp32.py` | Simulateur ESP32 Python (télémétrie 5s, ACK, 3 relays) |
| `workers/mqtt5-worker/index.js` | Souscrit télémétrie (`aricie/v1/boxes/+/telemetry`) |
| `workers/test/box/README.md` | Instructions simulateur |
| `supabase/migrations/20260627000006_boxes_user_id_nullable.sql` | ALTER boxes.user_id DROP NOT NULL |
| `supabase/migrations/20260627000007_boxes_uid_hardware_check.sql` | CHECK length(uid_hardware) > 8 |
| `supabase/migrations/20260628000001_energy_rollup.sql` | Energy_data : kwh + cumulative_kwh au lieu de total_day/week/month/year |
| `supabase/migrations/20260629000001_fix_rpc_group_by.sql` | Fix TOO_MANY_ROWS dans sum_total_consumption |
| `supabase/migrations/20260629000002_enable_realtime.sql` | Realtime broadcast sur energy_data + device_commands |
| `supabase/migrations/20261026000001_admin_geo.sql` | Geo boxes (lat/lng/precision/installed_at), coverage_zones, analytics_events, admin_notes |
| `supabase/migrations/20261026000002_admin_rbac.sql` | users.admin_level (viewer/operator/super_admin) + vue admin_coverage_view |
| `supabase/migrations/20261026000003_admin_kpi_rpcs.sql` | RPC admin_kpi_summary / admin_kpi_timeseries + enum admin_action_type étendu |

## Gotchas

- MQTT on web uses stub client (`mqtt/mqtt_web.dart`) — features limited
- Supabase URL/key required via `--dart-define` at compile time
- `mqtt_client` import from `src/typed_buffer.dart` directly (non-standard pattern)
- ~~`dependency_overrides.web: 1.1.1`~~ (removed — incompatible with Dart 3.7+; replaced with conditional imports for MQTT web/native client selection via `mqtt_client_factory*.dart`) pinned to avoid breaking changes
- Azure OpenAI secrets must be set in Supabase dashboard (Edge Functions secrets)
- `WEBHOOK_SECRET` required for mqtt-worker webhook security
- Phi-4-mini-instruct utilise l'API version `2024-06-01` (pas `2024-10-21` comme les modèles OpenAI)
- **Never commit secrets** — use `--dart-define` only
