# aricie — MindCare Energy

Application Flutter de suivi et gestion de consommation énergétique avec objets connectés.

## Stack

| Couche | Technologie |
|---|---|
| App | Flutter 3.29.0 (FVM) |
| Auth | Supabase Auth |
| Base de données | Supabase PostgreSQL |
| IoT | MQTT (mosquitto) via `mqtt_client` |
| IA | Flowise agent (chatbot) |
| Design | Soft Wellness Minimalism (voir `DESIGN.md`) |

## Architecture 2026

Le projet évolue vers une architecture multi-utilisateurs avec :

- **Rôles** : Admin / Utilisateur standard / VIP
- **Périmètres stricts** : Chaque utilisateur possède ses boîtiers, isolation totale
- **Abonnements** : Système de licence FREE/VIP
- **Synchronisation** : Paire unique boîtier ↔ utilisateur via UID matériel
- **Nouvelle BDD** : Tables `licences`, `subscriptions`, `sync_logs`, `admin_actions`, `roles`

Voir `AGENTS.md` pour les détails techniques et commandes.

## Démarrage rapide

```bash
fvm flutter pub get
fvm flutter run
```

## Screens

`Splash → Onboarding → Auth (Login/Signup) → Dashboard`
- Dashboard : température, humidité, consommation (temps réel MQTT)
- Statistiques : historique, tendances
- Appareils : gestion CRUD, contrôle on/off via MQTT
- Paramètres : thème, état MQTT, liste appareils
- Chatbot : Flowise AI intégré

## Licence

Projet privé — MindCare Energy
