# Changelog

## [1.4.0+1] — 2026-06-27

### Added
- MQTT singleton via `get_it` avec paramètre `force` dans `initialize()`
- `FLESPI_DEFAULT_BOX_UID` comme compile-time override pour fallback MQTT
- Simulateur ESP32 Python (`workers/test/box/box_esp32.py`) — télémétrie 5s, ACK, 3 relays
- Worker souscrit à la télémétrie (`aricie/v1/boxes/+/telemetry`)
- `SUPABASE_SERVICE_ROLE_KEY` dans le `.env` du worker
- Use-case admin `GetAvailableBoxes` pour lister les boîtiers non assignés

### Fixed
- `boxes.user_id` nullable (migration `20260627000006`) pour permettre les boîtiers sans propriétaire
- CHECK constraint `length(uid_hardware) > 8` (migration `20260627000007`)
- Dialog admin : `DropdownButtonFormField` utilise `value` au lieu de `initialValue`
- `MqttService.initialize(force: true)` ne recrée plus `_connectionStateController` — les `StreamBuilder` gardent leur abonnement
- SettingsScreen : padding bottom `kBottomNavigationBarHeight` pour éviter le débordement navbar
- Validation avec messages d'erreur explicites dans le dialog admin

### Changed
- Architecture MQTT : singleton partagé entre tous les screens, plus d'instances multiples
- Connexion MQTT initialisée depuis `HomeScreen` après chargement des appliances
- Worker : souscrit désormais à la télémétrie en plus des ACK
- `AdminRepository.createBox()` : userId nullable
- `SupabaseAdminDataSource.createBox()` : userId nullable

### Docs
- `AGENTS.md` : architecture MQTT singleton, nouvelles migrations, simulateur, relevant files
- `VERSION.md` : version bump + historique

## [1.3.0+1] — 2026-06-26

### Added
- Admin provisioning : création boîtiers/appareils depuis dashboard admin
- Pipeline stats : Edge Function energy-aggregator + LiveConsumptionIndicator
- Energy tips banner avec cron hebdomadaire
- Système de rotation des clés produit (cron hebdomadaire)

### Fixed
- `supabaseServiceRoleKey` et `flespiWorkerToken` retirés de `constants.dart`
- SettingsScreen : remplace Lottie empty state par message texte
- DevicesScreen : refonte lecture seule, toggle via `device_commands`

### Changed
- UI appareils refondue : lecture seule, catégories dérivées, FAB/MQTT supprimés
- Update service : redirect handling, CORS, `WRITE_EXTERNAL_STORAGE`

## [1.2.0+1] — 2026-06-26

### Added
- CI/CD release pipeline
- Preload subscription at boot

## [1.1.0+1] — 2026-06-25

### Added
- Agent RAG vectoriel 
- Subscription tiers (Premium/Gratuit)
- `device_commands` file d'attente IoT
- Tool calling avec Azure OpenAI

## [1.0.0+1] — 2026-06-21

### Added
- Initial release
- Auth email
- Dashboard, Stats, Devices, Settings
- Chatbot 
- MQTT 5.0 IoT avec Flespi
- Edge Functions Supabase
