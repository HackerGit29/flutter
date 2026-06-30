# Presentation Layer

UI components, state management, and screens.

## Screens
- **Auth**: `LoginScreen`, `SignupScreen`, `ResetPasswordScreen` (saisie code OTP + nouveau mot de passe après envoi par email depuis `LoginScreen`).
- **Core**: `SplashScreen`, `OnboardingScreen`, `HomeScreen` (tabs: Dashboard, Stats, Devices, Settings).
- **Dashboard** (`DashboardTab` intégré dans `HomeScreen`) :
  - Température/humidité temps réel depuis `BoxTelemetry` (stream MQTT unique)
  - Consommation journalière depuis `GetEnergyByAppliance`
  - **LiveConsumptionIndicator** : conso temps réel par appareil depuis `RealtimePowerService` (stream MQTT)
  - Grille d'appareils dynamique (nom, conso) issues de `GetUserAppliances`
  - `DailyEnergyTipBanner` : conseils d'économie depuis Edge Function
- **Features**:
  - `DevicesScreen`: Grille lecture seule des appliances avec toggle on/off. Catégories dérivées des données. Le toggle écrit dans `device_commands` (file d'attente worker MQTT5). Plus de FAB/add/delete (admin only).
  - `StatisticsScreen`: Graphique de consommation, répartition par appliance + **LiveConsumptionIndicator** en haut.
  - `ChatbotScreen`: AI assistant interface.
  - `ProfileScreen`: Détails du compte + lien vers Admin (visible si `isAdmin`).
  - `SettingsScreen`: Renommer/supprimer appliances, thème, statut MQTT.
- **Admin**:
  - `AdminDashboardScreen`: 3 tabs (Boîtiers, Utilisateurs, Synchronisations). FAB pour créer un boîtier + 3 appliances associées. Liste avec statut, navigation vers détails.
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
