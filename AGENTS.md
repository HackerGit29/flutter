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
| Backend | Supabase (auth, realtime streams, PostgreSQL) |
| IoT | MQTT via `mqtt_client` (WSS/TLS: `wss://broker.aricie.energy:8883`) |
| AI | Flowise agent (chatbot) |
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
    datasources/             ← SupabaseAuth, SupabaseDevice, SupabaseLicense, SupabaseAdmin, SupabaseSync, Local
    repositories/            ← AuthRepositoryImpl, DeviceRepositoryImpl, LicenseRepositoryImpl, AdminRepositoryImpl, SyncRepositoryImpl
  domain/                    ← Entities, repository interfaces, use-cases
    entities/                ← User, Device, Subscription, License, SyncLog, AdminAction
    repositories/            ← Abstract interfaces (5)
    usecases/                ← 26 use-cases across auth, devices, license, admin, sync
  presentation/              ← Screens, widgets, theme
    screens/                 ← Auth, Home (Dashboard/Stats/Devices/Settings), Admin, Chatbot
    widgets/                 ← PremiumGateWidget, MetricChart, ChatBubble
    theme/                   ← app_theme.dart (light/dark, Material 3)
```

## Key entrypoints

| File | Role |
|------|------|
| `lib/main.dart` | App initialization: Supabase, notifications, splash → auth flow |
| `lib/services/mqtt_service.dart` | IoT messaging (telemetry stream, control commands) |
| `lib/services/auth_service.dart` | High-level auth wrapper (uses secure storage) |
| `lib/services/agent_service.dart` | Flowise AI chatbot integration |
| `lib/services/notification_service.dart` | Local and push notifications |
| `lib/theme/app_theme.dart` | Light/dark theme (Material 3, seed `#4A6572`) |
| `lib/screens/home_screen.dart` | Main dashboard (tabs: Dashboard, Stats, Devices, Settings) |
| `lib/core/constants.dart` | Environment-based configuration |
| `lib/core/di/injection_container.dart` | get_it DI container |

## Database (Supabase)

Key tables: `boxes`, `appliances`, `energy_data`, `sync_logs`, `admin_actions`

All tables use `user_id` FK for ownership and enforce RLS. Admin bypass via JWT role claim.

Full schema in `docs/supabase/init_db.sql`.

## 2026 project evolution (in progress)

- **Role-based access**: Admin manages users; users own their devices; strict perimeter separation
- **VIP subscription**: License/abonnement system with premium features (advanced sync, extended storage)
- **Device sync**: Unique pairing via hardware UID; device belongs to exactly one user at a time
- **Target schema**: Users → Devices (owns), Users → Subscriptions (has), Subscriptions → Licenses (activates), Devices → SyncLogs (generates)
- **Authentication**: Required before any operation

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
- Scopes: `auth`, `devices`, `license`, `admin`, `sync`, `core`, `data`, `domain`, `ui`, `mqtt`, `supabase`, `deps`

## Versioning

Semantic Versioning 2.0.0. Canonical version in `pubspec.yaml`. See `VERSION.md`.

## Gotchas

- MQTT on web uses stub client (`mqtt/mqtt_web.dart`) — features limited
- Supabase URL/key required via `--dart-define` at compile time
- `mqtt_client` import from `src/typed_buffer.dart` directly (non-standard pattern)
- `dependency_overrides.web: 1.1.1` pinned to avoid breaking changes
- **Never commit secrets** — use `--dart-define` only
