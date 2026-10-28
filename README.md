# Aricie - ETSIA 2026

Application Flutter de suivi et gestion de consommation énergétique avec objets connectés.

## Stack

| Couche          | Technologie                                           |
| --------------- | ----------------------------------------------------- |
| App             | Flutter (latest stable)                                  |
| State           | Riverpod + Provider                                   |
| Auth            | Supabase Auth                                         |
| Base de données | Supabase PostgreSQL                                   |
| IoT             | MQTT 5.0 (TCP TLS/WSS) via `mqtt5_client` (app subscribe telemetry/status; worker publie commandes via `device_commands`) |
| IA              | Agent‑orchestrator (chaîne LLM : OpenCode bridge → DeepSeek → Cloudflare Workers AI) avec RAG pgvector, streaming SSE, policy engine et file d’attente de commandes MQTT |
| Architecture    | Clean Architecture (core/data/domain/presentation)    |

## Requirements

### Development Environment

| Requirement | Version | Notes                            |
| ----------- | ------- | -------------------------------- |
| Flutter     | latest stable | Install from https://flutter.dev |
| Dart SDK    | ^3.7.0        | Defined in `pubspec.yaml`        |
| Supabase    | ^2.8.4        | Account required for credentials |

### Hardware / OS

- **Target platforms**: Android, iOS, Web, Windows, macOS
- **Minimum Android SDK**: 21 (Android 5.0)
- **Target iOS**: 12.0+
- **Development**: Windows, macOS, or Linux

### Runtime Dependencies

| Dependency                               | Purpose                                  |
| ---------------------------------------- | ---------------------------------------- |
| `supabase_flutter`                       | Authentication, realtime, PostgreSQL     |
| `mqtt_client`                            | IoT device communication (MQTT)          |
| `flutter_riverpod`                       | State management                         |
| `get_it` + `dartz`                       | DI container + functional error handling |
| `flutter_secure_storage`                 | Secure token storage                     |
| `shared_preferences`                     | Non-sensitive session cache              |
| `fl_chart` / `syncfusion_flutter_charts` | Energy consumption charts                |
| `google_fonts`                           | DM Sans typography                       |
| `lottie`                                 | Animations                               |
| `flutter_local_notifications`            | Push and local notifications             |

### API Credentials

The following environment variables are required at compile time via `--dart-define`:

| Variable            | Description                |
| ------------------- | -------------------------- |
| `SUPABASE_URL`      | Supabase project URL       |
| `SUPABASE_ANON_KEY` | Supabase anonymous API key |

> **Security**: Never commit credentials to source code. Use `--dart-define` flags only.

## Architecture 2026

Le projet a évolué vers une architecture multi-utilisateurs avec :

- **Rôles** : Admin / Utilisateur standard / VIP
- **Périmètres stricts** : Chaque utilisateur possède ses boîtiers, isolation totale
- **Abonnements** : Système de licence FREE/VIP
- **Synchronisation** : Paire unique boîtier ↔ utilisateur via UID matériel
- **Provisionnement admin** : Création boîtiers + appareils depuis dashboard admin (plus de CRUD utilisateur)
- **Pipeline stats** : Edge Function `energy-aggregator` + `LiveConsumptionIndicator` pour conso temps réel
- **Toggle IoT** : Toute commande appareil passe par `device_commands` (file d'attente worker MQTT5)
- **Nouvelle BDD** : Tables `licences`, `subscriptions`, `sync_logs`, `admin_actions`, `roles`, migrations `20260623000001` (agent) et `20260626000003` (admin)

Voir `AGENTS.md` pour les détails techniques et commandes.

## Démarrage rapide

```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

Ou configuration via variable d'environnement :

```bash
$env:SUPABASE_URL = "https://xxxxxxxxxxxxxx.supabase.co"
$env:SUPABASE_ANON_KEY = "xxxxxxxxxx"
flutter run
```

## Screens

`Splash → Onboarding → Auth (Login/Signup) → Dashboard`

- Dashboard : température, humidité, consommation temps réel (MQTT), **conso live par appareil**, conseils économie
- Statistiques : historique, tendances, **conso live en haut de page**
- Appareils : lecture seule, toggle via `device_commands` (admin crée les boîtiers depuis le dashboard admin)
- Paramètres : thème, état MQTT, liste appareils, bouton « Donner un avis » (formulaire de retours utilisateurs)
- Chatbot : agent‑orchestrator (chaîne LLM OpenCode → DeepSeek → Cloudflare, embeddings RAG encore Azure) avec streaming SSE
- Administration : gestion utilisateurs, boîtiers, licences, **création de boîtiers + 3 appareils** (admin only)

## Contribuer

Voir [CONTRIBUTING.md](CONTRIBUTING.md) pour les conventions de code, commits, branches et le processus de pull request.

## Versioning

Voir [VERSION.md](VERSION.md).

## Sécurité

Voir [SECURITY.md](SECURITY.md) pour les standards de sécurité et la procédure de signalement de vulnérabilités.

## Licence

Distribué sous licence MIT. Voir [LICENSE](LICENSE).

Projet académique ETSIA — Partenariat professionnel Bedouen KANKEU.
