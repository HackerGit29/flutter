# AGENTS.md — aricie (MindCare Energy)

## Quick start
```bash
fvm flutter run           # Start dev app
fvm flutter test           # Run widget tests (no integration test suite yet)
fvm flutter analyze        # Lint check (uses flutter_lints)
fvm flutter build apk      # Release build
```

## Stack
- **App**: Flutter 3.29.0 (FVM-managed, see `.fvmrc`)
- **State**: Provider (theme) + Riverpod (listed in pubspec, partially adopted)
- **Backend**: Supabase (auth, realtime streams, PostgreSQL — url/key in `lib/main.dart:31-34`)
- **IoT**: MQTT via `mqtt_client` to `test.mosquitto.org` (dev broker)
- **AI**: Flowise agent at `https://micro.uksouth.cloudapp.azure.com/...` (chatbot)
- **Design**: DESIGN.md — Soft Wellness Minimalism, pastel palette, DM Sans typography
- **Current theme**: `lib/theme/app_theme.dart` (Material 3, seed `#4A6572`)

## Project conventions
- Package: `aricie` (pubspec name)
- All user-facing strings in French
- Navigation: `Navigator.push` / `pushReplacement` (no GoRouter)
- Dev dependency: `dependency_overrides.web: 1.1.1` (pin to avoid breaking changes)
- Static analysis: `lib/` checked via `fvm flutter analyze`; MQTT-related errors may appear on web (expected, uses conditionals)

## Key entrypoints
| File | Role |
|---|---|
| `lib/main.dart` | App init: Supabase.initialize, notifications, splash → auth flow |
| `lib/services/supabase_service.dart` | Realtime data streams (temp, humidity, energy) from Supabase |
| `lib/services/mqtt_service.dart` | IoT device messaging (3 devices, energy + control topics) |
| `lib/services/auth_service.dart` | Supabase auth + SharedPreferences session cache |
| `lib/theme/app_theme.dart` | light/dark theme definition |
| `lib/screens/home_screen.dart` | Main dashboard with tabs (Dashboard, Stats, Devices, Settings) |

## Database (Supabase)
Key tables: `devices`, `temp_data`, `hum_data`, `energy_consumption`, `alerts`

All tables use `user_id` FK for ownership. Devices are scoped per user.

## 2026 project evolution (in progress)
New architecture adds:
- **Role-based access**: Admin manages users; users own their devices; strict perimeter separation (`user_id` → device ownership enforced)
- **VIP subscription**: License/abonnement system with premium features (advanced sync, extended storage)
- **Device sync**: Unique pairing via hardware UID; device belongs to exactly one user at a time
- **DB remodelling**: New tables needed — `licences`, `subscriptions`, `sync_logs`, `admin_actions`, `roles`
- **Authentication**: Required before ANY operation (design diagram: auth → all use cases include auth)
- **Target DB schema**: Users → Devices (owns), Users → Subscriptions (has), Subscriptions → Licences (activates), Devices → SyncLogs (generates)

## Design system (2026)
- Full spec in `DESIGN.md` — use as source of truth for all new screens
- Color accent: rgb(121, 207, 244) for system-level diagrams
- Soft Wellness Minimalism: pastels, rounded corners (min 12px), DM Sans font, generous padding
- Target screen: 375×812px (iPhone)

## Commands cheat sheet
```bash
fvm flutter clean && fvm flutter pub get   # Reset deps
fvm dart run flutter_launcher_icons        # Regenerate icons
```

## Testing
- `test/widget_test.dart` is a placeholder, needs rewrite
- No integration or unit tests for services yet

## Gotchas
- MQTT on web uses stub client: `mqtt/mqtt_web.dart` — features limited
- Supabase URL/key are hardcoded in `main.dart` — committed, not env-managed
- `mqtt_client` import from `src/typed_buffer.dart` directly (non-standard pattern)
- Two theme files exist: `lib/theme/app_theme.dart` (used) and `lib/utils/theme.dart` (legacy/orphaned)
- Two `MyApp` widgets: `lib/main.dart` (used) and `lib/app.dart` (unused)
