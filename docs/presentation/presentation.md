# Presentation Layer

UI components, state management, and screens.

## Screens
- **Auth**: `LoginScreen`, `SignupScreen`.
- **Core**: `SplashScreen`, `OnboardingScreen`, `HomeScreen` (tabs: Dashboard, Stats, Devices, Settings).
- **Dashboard** (`DashboardTab` intégré dans `HomeScreen`) :
  - Température/humidité temps réel depuis `BoxTelemetry` (stream MQTT unique)
  - Consommation journalière depuis `GetEnergyByAppliance`
  - Grille d'appareils dynamique (nom, conso) issues de `GetUserAppliances`
- **Features**:
  - `DevicesScreen`: Grille de toutes les appliances avec toggle MQTT. États des relais lus depuis `telemetryStream` (`BoxTelemetry.relays`). Contrôle via `sendControlCommand(boxUid, relayIndex)`.
  - `StatisticsScreen`: Graphique de consommation et répartition par appliance via `energy_data`.
  - `ChatbotScreen`: AI assistant interface.
  - `ProfileScreen`: Détails du compte + lien vers Admin (visible si `isAdmin`).
  - `SettingsScreen`: Renommer/supprimer appliances, thème, statut MQTT.
- **Admin**:
  - `AdminDashboardScreen`: 3 tabs (Boîtiers, Utilisateurs, Synchronisations). Liste avec statut, navigation vers détails.
  - `AdminBoxDetailScreen`: Infos boîtier, assigner utilisateur, réinitialiser, historique sync.
  - `AdminUserDetailScreen`: Infos utilisateur, suspendre/activer, changer rôle, liste des boîtiers.

## State Management
- `ThemeProvider`: Manages light/dark themes via Provider (utilisé dans `SettingsScreen`).

## Widgets
- `CommonHeader`: Titre + bouton profil (utilisé par DevicesScreen, SettingsScreen).
- `MetricChart`: Visualization of telemetry data.
- `PremiumFeatureGate`: Conditional widget for VIP-only features.
- `ChatBubble`: UI for AI conversations.
- `TypingIndicator`, `ChatInput`: Composants du chat.
