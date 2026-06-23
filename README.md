# Aricie - ETSIA 2026

Application Flutter de suivi et gestion de consommation énergétique avec objets connectés.

## Stack

| Couche          | Technologie                                           |
| --------------- | ----------------------------------------------------- |
| App             | Flutter 3.29.0 (FVM)                                  |
| State           | Riverpod + Provider                                   |
| Auth            | Supabase Auth                                         |
| Base de données | Supabase PostgreSQL                                   |
| IoT             | MQTT (WSS/TLS) via `mqtt_client`                      |
| IA              | Flowise agent (chatbot)à revoir avec les nouveaux SDK |
| Architecture    | Clean Architecture (core/data/domain/presentation)    |

## Requirements

### Development Environment

| Requirement | Version | Notes                            |
| ----------- | ------- | -------------------------------- |
| Flutter     | 3.29.0  | FVM-managed (see `.fvmrc`)       |
| Dart SDK    | ^3.7.0  | Defined in `pubspec.yaml`        |
| Supabase    | ^2.8.4  | Account required for credentials |
| FVM         | latest  | Optional but recommended         |

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
- **Nouvelle BDD** : Tables `licences`, `subscriptions`, `sync_logs`, `admin_actions`, `roles`

Voir `AGENTS.md` pour les détails techniques et commandes.

## Démarrage rapide

```bash
fvm flutter pub get
fvm flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

Ou configuration via variable d'environnement :

```bash
$env:SUPABASE_URL = "https://votre-projet.supabase.co"
$env:SUPABASE_ANON_KEY = "votre-cle-anon"
fvm flutter run
```

## Screens

`Splash → Onboarding → Auth (Login/Signup) → Dashboard`

- Dashboard : température, humidité, consommation (temps réel MQTT)
- Statistiques : historique, tendances
- Appareils : gestion CRUD, contrôle on/off via MQTT
- Paramètres : thème, état MQTT, liste appareils
- Chatbot : Flowise AI intégré
- Administration : gestion utilisateurs, boîtiers, licences (admin only)

## Contribuer

Voir [CONTRIBUTING.md](CONTRIBUTING.md) pour les conventions de code, commits, branches et le processus de pull request.

## Versioning

Ce projet suit [SemVer 2.0.0](https://semver.org/). Voir [VERSION.md](VERSION.md).

## Sécurité

Voir [SECURITY.md](SECURITY.md) pour les standards de sécurité et la procédure de signalement de vulnérabilités.

## Licence

Distribué sous licence MIT. Voir [LICENSE](LICENSE).

Projet académique ETSIA — Partenariat professionnel Bedouen KANKEU.
