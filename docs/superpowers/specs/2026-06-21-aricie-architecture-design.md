# aricie — Architecture Design 2026

**Date** : 2026-06-21
**Status** : Design approved, awaiting implementation

## Contexte

L'application "aricie" est un moniteur énergétique Flutter avec boîtiers IoT connectés.
Le projet évolue vers une plateforme multi-utilisateurs avec séparation stricte des périmètres,
système de licences, administration centralisée, et synchronisation sécurisée des boîtiers.

---

## 1. Architecture cible

```
lib/
  main.dart
  core/
    constants.dart
    errors/
      failures.dart              ← sealed class Failure
    network/
      supabase_client.dart        ← Singleton Supabase
      mqtt_client.dart            ← Refactored MqttService
    di/
      injection_container.dart    ← get_it service locator
    security/
      token_manager.dart          ← JWT refresh, secure storage
      device_crypto.dart          ← UID signing, anti-replay
      rate_limiter.dart           ← Rate limiting sync & admin
  data/
    datasources/
      supabase_auth_datasource.dart
      supabase_device_datasource.dart
      supabase_license_datasource.dart
      supabase_admin_datasource.dart
      supabase_sync_datasource.dart
      mqtt_datasource.dart
      local_datasource.dart
    repositories/
      auth_repository_impl.dart
      device_repository_impl.dart
      license_repository_impl.dart
      admin_repository_impl.dart
      sync_repository_impl.dart
  domain/
    entities/
      user.dart
      device.dart
      subscription.dart
      license.dart
      sync_log.dart
      admin_action.dart
    repositories/
      auth_repository.dart         ← abstract
      device_repository.dart
      license_repository.dart
      admin_repository.dart
      sync_repository.dart
    usecases/
      auth/
        login_user.dart
        register_user.dart
        logout_user.dart
        get_current_user.dart
        refresh_token.dart
      devices/
        add_device.dart
        remove_device.dart
        get_user_devices.dart
        toggle_device.dart
        identify_device.dart
        pair_device_with_uid.dart
      license/
        get_user_subscription.dart
        upgrade_to_vip.dart
        cancel_subscription.dart
        check_license_validity.dart
        is_feature_allowed.dart
      admin/
        get_all_users.dart
        suspend_user.dart
        activate_user.dart
        assign_role.dart
        get_all_devices.dart
        get_sync_logs.dart
        assign_device.dart
        reset_device.dart
        force_sync.dart
        override_ownership.dart
      sync/
        request_sync.dart
        validate_device_ownership.dart
        verify_device_crypto_uid.dart
        log_sync_result.dart
  presentation/
    providers/                    ← Riverpod
    screens/
      splash_screen.dart
      onboarding_screen.dart
      auth/
        login_screen.dart
        signup_screen.dart
      home_screen.dart
      dashboard/
      devices/
        devices_screen.dart
        device_sync_screen.dart     ← Pairage UID
      license/
        license_screen.dart         ← Statut abonnement
        upgrade_screen.dart         ← Upgrade VIP
        premium_feature_gate.dart   ← Widget conditionnel
      admin/
        admin_panel_screen.dart
        user_management_screen.dart
        license_management_screen.dart
        device_management_screen.dart
        system_logs_screen.dart
      settings/
      profile/
    widgets/
      premium_gate_widget.dart      ← Affiche "Passer en VIP" si FREE
    theme/
```

---

## 2. Domain entities

### User
| Field | Type | Notes |
|---|---|---|
| id | String | UUID |
| email | String | Unique, validated |
| passwordHash | String | bcrypt via Supabase Auth |
| role | Role | admin / user / vip |
| status | UserStatus | active / suspended |
| createdAt | DateTime | |
| subscriptionId | String? | FK → Subscription.id |

### Role (enum)
```
admin → full system access
user  → standard device owner
vip   → user with premium features
```

### UserStatus (enum)
```
active    → normal operation
suspended → blocked by admin, cannot login
```

### Device
| Field | Type | Notes |
|---|---|---|
| id | String | UUID |
| uidHardware | String | **Unique**, identifiant physique soudé en EEPROM/OTP |
| name | String | Nom donné par l'utilisateur |
| status | DeviceStatus | active / inactive / blocked |
| userId | String | FK → User.id (propriétaire) |
| publicKey | String? | Clé publique pour vérification crypto |
| lastSync | DateTime? | Dernière synchronisation |
| firmwareVersion | String? | Version du firmware embarqué |
| createdAt | DateTime | |

### DeviceStatus (enum)
```
active   → opérationnel, peut sync
inactive → pas de sync récente
blocked  → bloqué par admin (vol, perte, anomalie)
```

### Subscription
| Field | Type | Notes |
|---|---|---|
| id | String | UUID |
| userId | String | FK → User.id, **unique** (1 seul abonnement actif par user) |
| type | SubscriptionType | free / vip |
| startDate | DateTime | |
| endDate | DateTime | NULL si free, défini si vip |
| isActive | bool | true si en cours de validité |
| autoRenew | bool | true si renouvellement automatique |
| createdAt | DateTime | |

**Règle** : Un user ne peut avoir qu'**une seule** Subscription active à la fois.
**Règle** : FREE = perpétuel, pas de date de fin. VIP = période définie.

### SubscriptionType (enum)
```
free → features de base
vip  → fonctionnalités premium (sync avancée, historique étendu, support prioritaire)
```

### License
| Field | Type | Notes |
|---|---|---|
| id | String | UUID |
| subscriptionId | String | FK → Subscription.id |
| activationDate | DateTime | Date d'activation |
| expirationDate | DateTime | Date d'expiration (même que Subscription.endDate) |
| licenseKey | String | Clé de licence unique |

**Règle** : Une License ne peut exister sans Subscription parent.
**Règle** : Créée automatiquement lors de l'upgrade VIP.
**Règle** : isValid = `now >= activationDate && now <= expirationDate && parentSubscription.isActive`.

### SyncLog
| Field | Type | Notes |
|---|---|---|
| id | String | UUID |
| deviceId | String | FK → Device.id |
| userId | String | FK → User.id |
| status | SyncStatus | success / failed / unauthorized / crypto_mismatch |
| data | Map<String, dynamic>? | Payload JSONB de la sync (température, énergie, etc.) |
| errorMessage | String? | Message d'erreur si échec |
| ipAddress | String? | Adresse IP de la requête |
| timestamp | DateTime | |

### SyncStatus (enum)
```
success          → sync réussie
failed           → erreur technique
unauthorized     → user non propriétaire du device
crypto_mismatch  → signature UID invalide
device_blocked   → device.status == blocked
```

### AdminAction
| Field | Type | Notes |
|---|---|---|
| id | String | UUID |
| adminId | String | FK → User.id |
| action | AdminActionType | enum des actions possibles |
| targetType | TargetType | user / device / license / subscription |
| targetId | String | ID de la cible |
| details | Map<String, dynamic>? | Contexte additionnel |
| timestamp | DateTime | |

### AdminActionType (enum)
```
suspend_user / activate_user / assign_role
reset_device / force_sync / override_ownership / block_device
activate_license / revoke_license
```

### TargetType (enum)
```
user / device / license / subscription
```

---

## 3. Core / Errors (Failures)

```dart
sealed class Failure {}
class ServerFailure extends Failure {}
class NetworkFailure extends Failure {}
class CacheFailure extends Failure {}

// Auth
class AuthFailure extends Failure {}
class InvalidCredentialsFailure extends AuthFailure {}
class SessionExpiredFailure extends AuthFailure {}
class TokenRefreshFailure extends AuthFailure {}
class AccountSuspendedFailure extends AuthFailure {}

// Device ownership
class DeviceOwnershipFailure extends Failure {}
class DeviceNotFoundFailure extends Failure {}
class DeviceAlreadyAssignedFailure extends Failure {}
class DeviceNotIdentifiedFailure extends Failure {}
class DeviceCryptoMismatchFailure extends Failure {}
class DeviceBlockedFailure extends Failure {}

// License
class LicenseExpiredFailure extends Failure {}
class NoActiveSubscriptionFailure extends Failure {}
class AlreadyHasActiveSubscriptionFailure extends Failure {}
class FeatureNotAllowedFailure extends Failure {}  // feature requires VIP

// Admin
class AdminPermissionFailure extends Failure {}
class CannotModifySelfFailure extends Failure {}
class CannotModifySuperAdminFailure extends Failure {}

// Sync
class SyncUnauthorizedFailure extends Failure {}
class SyncRateLimitFailure extends Failure {}
class SyncInProgressFailure extends Failure {}
```

---

## 4. DB schema (Supabase)

### Tables existantes — modifications

```sql
-- users : ajout colonnes
ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'user' CHECK (role IN ('admin', 'user', 'vip'));
ALTER TABLE users ADD COLUMN status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended'));

-- devices : ajout colonnes
ALTER TABLE devices ADD COLUMN uid_hardware TEXT UNIQUE;
ALTER TABLE devices ADD COLUMN status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'blocked'));
ALTER TABLE devices ADD COLUMN last_sync TIMESTAMPTZ;
ALTER TABLE devices ADD COLUMN public_key TEXT;
ALTER TABLE devices ADD COLUMN firmware_version TEXT;

-- devices : index sur uid_hardware
CREATE UNIQUE INDEX idx_devices_uid_hardware ON devices(uid_hardware) WHERE uid_hardware IS NOT NULL;
CREATE INDEX idx_devices_user_id ON devices(user_id);
```

### Nouvelles tables

```sql
-- subscriptions : un user = une subscription active max
CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type TEXT NOT NULL DEFAULT 'free' CHECK (type IN ('free', 'vip')),
  start_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  end_date TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT true,
  auto_renew BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_active_subscription UNIQUE (user_id)  -- 1 seul abonnement actif par user
);

-- licenses : liée à une subscription
CREATE TABLE licenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
  activation_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expiration_date TIMESTAMPTZ,
  license_key TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- sync_logs
CREATE TABLE sync_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id),
  status TEXT NOT NULL CHECK (status IN ('success', 'failed', 'unauthorized', 'crypto_mismatch', 'device_blocked')),
  data JSONB,
  error_message TEXT,
  ip_address TEXT,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_sync_logs_device_id ON sync_logs(device_id);
CREATE INDEX idx_sync_logs_user_id ON sync_logs(user_id);
CREATE INDEX idx_sync_logs_timestamp ON sync_logs(timestamp DESC);

-- admin_actions
CREATE TYPE admin_action_type AS ENUM (
  'suspend_user', 'activate_user', 'assign_role',
  'reset_device', 'force_sync', 'override_ownership', 'block_device',
  'activate_license', 'revoke_license'
);
CREATE TYPE target_type AS ENUM ('user', 'device', 'license', 'subscription');

CREATE TABLE admin_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID NOT NULL REFERENCES users(id),
  action admin_action_type NOT NULL,
  target_type target_type NOT NULL,
  target_id TEXT NOT NULL,
  details JSONB,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_admin_actions_admin_id ON admin_actions(admin_id);
CREATE INDEX idx_admin_actions_timestamp ON admin_actions(timestamp DESC);
```

### RLS Policies

```sql
-- devices : user voit ses devices, admin voit tout
CREATE POLICY devices_user_select ON devices FOR SELECT
  USING (user_id = auth.uid() OR auth.jwt()->>'role' = 'admin');
CREATE POLICY devices_user_insert ON devices FOR INSERT
  WITH CHECK (user_id = auth.uid());
CREATE POLICY devices_user_update ON devices FOR UPDATE
  USING (user_id = auth.uid() OR auth.jwt()->>'role' = 'admin');
CREATE POLICY devices_user_delete ON devices FOR DELETE
  USING (user_id = auth.uid() OR auth.jwt()->>'role' = 'admin');

-- subscriptions : user voit la sienne, admin voit tout
CREATE POLICY subscriptions_select ON subscriptions FOR SELECT
  USING (user_id = auth.uid() OR auth.jwt()->>'role' = 'admin');

-- sync_logs : user voit ses logs, admin voit tout
CREATE POLICY sync_logs_select ON sync_logs FOR SELECT
  USING (user_id = auth.uid() OR auth.jwt()->>'role' = 'admin');

-- admin_actions : admin only
CREATE POLICY admin_actions_select ON admin_actions FOR SELECT
  USING (auth.jwt()->>'role' = 'admin');
CREATE POLICY admin_actions_insert ON admin_actions FOR INSERT
  WITH CHECK (auth.jwt()->>'role' = 'admin');
```

### Migration des données existantes

1. Les users existants reçoivent `role = 'user'`, `status = 'active'`
2. Les devices existants : `uid_hardware` = NULL temporairement (sera défini au prochain pairage)
3. Créer une Subscription FREE automatique pour chaque user existant
4. Les devices existants gardent leur `user_id` actuel
5. Backfill `sync_logs` impossible (pas de données historiques) — démarrer de zéro

---

## 5. Services & Use-cases

### Auth

| Use-case | Input | Output | Préconditions |
|---|---|---|---|
| `LoginUser` | email, password | User | Compte non suspendu |
| `RegisterUser` | email, password | User | Email unique |
| `LogoutUser` | — | void | Authentifié |
| `GetCurrentUser` | — | User? | — |
| `RefreshToken` | refreshToken | String (new JWT) | Refresh token valide |

**Flux** : Login → save tokens in secure storage → redirect to Home.
Token refresh automatique avant expiration.

### Devices

| Use-case | Input | Output | Préconditions |
|---|---|---|---|
| `AddDevice` | name, location | Device | Authentifié |
| `RemoveDevice` | deviceId | void | Owner |
| `GetUserDevices` | — | List<Device> | Authentifié |
| `ToggleDevice` | deviceId, bool on/off | void | Owner, MQTT command |
| `IdentifyDevice` | uidHardware | Device | UID existe en base |
| `PairDeviceWithUid` | deviceId, uidHardware, signature | Device | Owner, UID non assigné |

**Topics MQTT** (inchangés par rapport à l'existant) :
```
sensors/temperature      ← température
sensors/humidity         ← humidité
energy/data/{deviceId}   ← consommation par boîtier
device/control/{deviceId} ← commande on/off (QoS 2)
```
**Sécurité MQTT** : Actuellement test.mosquitto.org (dev). En prod → broker avec TLS + authentification client.

### License

| Use-case | Input | Output | Préconditions |
|---|---|---|---|
| `GetUserSubscription` | — | Subscription | Authentifié |
| `UpgradeToVip` | licenseKey | Subscription | Pas de subscription VIP active |
| `CancelSubscription` | — | Subscription | VIP actif |
| `CheckLicenseValidity` | — | bool | Authentifié |
| `IsFeatureAllowed` | featureName | bool | — |

**Règles** :
- Un user ne peut pas avoir plusieurs subscriptions actives (`UNIQUE(user_id)` en DB)
- Une license ne peut exister sans subscription (FK + création automatique)
- VIP active des feature gates dans l'UI (PremiumFeatureGate widget)
- `IsFeatureAllowed` check : `subscription.isActive && type == vip && license.isValid`

**Feature gates** :
- `historical_data_extended` : historique > 30 jours (VIP)
- `advanced_sync` : sync plus fréquente (VIP)
- `priority_support` : support prioritaire (VIP)
- `multi_device` : > 3 boîtiers (VIP)

### Admin

| Use-case | Input | Output | RBAC |
|---|---|---|---|
| `GetAllUsers` | filters | List<User> | admin |
| `SuspendUser` | userId | User | admin, pas self, pas super-admin |
| `ActivateUser` | userId | User | admin |
| `AssignRole` | userId, role | User | admin, pas self |
| `GetAllDevices` | filters | List<Device> | admin |
| `GetSyncLogs` | filters | List<SyncLog> | admin |
| `AssignDevice` | deviceId, newUserId | Device | admin |
| `ResetDevice` | deviceId | Device | admin |
| `ForceSync` | deviceId | SyncLog | admin |
| `OverrideOwnership` | deviceId, newUserId | void | admin, logged in admin_actions |

**Restrictions admin** :
- Un admin ne peut pas se suspendre/ban himself
- Un admin ne peut pas modifier un autre admin de même niveau ou supérieur
- Toutes les actions critiques sont loggées dans `admin_actions`
- `OverrideOwnership` nécessite une confirmation explicite (logged + requires justification)

### Sync

**Flux complet de synchronisation** (aligned with UML sequence diagram) :

```
1. AUTH : User → App → Backend : vérifier token
2. OWNERSHIP : App → Backend : validate device.userId == auth.uid
3. UNIQUE SYNC : Backend → DB : vérifier device non lié à un autre user
4. CRYPTO UID : Backend → Device : challenge-response avec clé privée
   - Backend envoie un nonce aléatoire
   - Device signe le nonce avec sa clé privée
   - Backend vérifie avec la clé publique stockée (uid_hardware + signature)
5. SYNC DATA : Device → Backend → DB : envoi des données mesurées
6. LOG : Backend → sync_logs : enregistrer résultat (success/failed/...)
7. RESPONSE : Backend → App : données synchronisées + statut
```

| Use-case | Input | Output | Préconditions |
|---|---|---|---|
| `RequestSync` | deviceId | SyncLog | Auth + Owner |
| `ValidateDeviceOwnership` | deviceId, userId | bool | — |
| `VerifyDeviceCryptoUid` | deviceId, signature, nonce | bool | Device has publicKey |
| `LogSyncResult` | deviceId, userId, status, data | SyncLog | — |

**Gestion des erreurs Sync** :
- `unauthorized` : tentative d'un non-owner → log + alerte
- `crypto_mismatch` : signature invalide → device suspect, log + notifier admin
- `device_blocked` : device.status == blocked → sync refusée
- `rate_limit` : > N syncs/minute → 429 Too Many Requests

---

## 6. Security module

| Component | Rôle |
|---|---|
| `TokenManager` | Stockage sécurisé des tokens (flutter_secure_storage), refresh automatique, détection expiration |
| `DeviceCrypto` | Challenge-response handshake : génération nonce, vérification signature ECDSA, anti-replay (timestamp + nonce) |
| `RateLimiter` | Limite : 10 syncs/minute par device, 5 tentatives admin actions/minute |

**Anti-replay** : Chaque requête sync inclut un nonce + timestamp. Le backend vérifie :
- timestamp dans une fenêtre de 60 secondes
- nonce jamais utilisé (stocké en cache Redis ou table)
- signature valide (ECDSA avec clé publique du device)

---

## 7. Flux complets

### Flux inscription
```
Splash → Onboarding → Signup → Supabase Auth → Création user (role=user, status=active)
    → Création Subscription FREE automatique → Home
```

### Flux ajout boîtier
```
Appareils → Ajouter → Saisir nom + emplacement → Supabase INSERT devices(user_id)
    → Appareil créé (uid_hardware=NULL, status=inactive)
    → Pairage : DeviceSyncScreen → scan UID → PairDeviceWithUid
    → Device.status = active → prêt pour sync
```

### Flux sync
```
Dashboard/Timer → RequestSync(deviceId) → Auth check → Ownership check
    → Crypto UID verify → Device envoie data → Backend enregistre + SyncLog
    → UI mise à jour avec nouvelles données
```

### Flux upgrade VIP
```
Abonnement → Voir plans → Upgrade VIP → Paiement (Stripe/...)
    → Backend : créer Subscription(type=vip) + License(licenseKey)
    → Désactiver ancienne subscription FREE
    → UI : premium features débloquées
```

### Flux admin — suspendre un user
```
Admin Panel → User Management → Sélectionner user → Suspendre
    → Backend : User.status = suspended
    → AdminAction loggée
    → L'utilisateur ne peut plus se connecter (LoginUser check status)
```

---

## 8. Navigation et contrôle d'accès

```
Splash → Onboarding → Login/Signup
    ↓ (session OK)
HomeScreen
  ├─ Dashboard (tous) → metrics temps réel
  ├─ Appareils (tous) → CRUD + sync UID
  ├─ Abonnement (tous) → statut, upgrade si FREE, cancel si VIP
  ├─ Paramètres (tous) → profil, thème, MQTT status
  └─ Administration (role=admin) ← invisible pour non-admin
       ├─ Utilisateurs → lister, suspendre, activer, changer rôle
       ├─ Licences → gérer subscriptions, activer/révoquer
       ├─ Boîtiers → tous les devices, réassigner, reset, force sync
       └─ Logs système → sync_logs, admin_actions
```

Premium Feature Gate :
```dart
// presentation/widgets/premium_gate_widget.dart
// Affiche le contenu premium si VIP, sinon un CTA "Passer en VIP"
class PremiumFeatureGate extends StatelessWidget {
  final Widget premiumChild;
  final Widget fallback; // "Passez en VIP pour débloquer"
}
```

---

## 9. Conformité rules.md

| Règle | Application |
|---|---|
| §2 Sécurité secrets | Supabase URL/key → `--dart-define` ou `.env`, jamais commité |
| §5 Clean Architecture | Dépendances vers l'intérieur (UI → UseCases → Repository interfaces → Datasources) |
| §6 Qualité code | `flutter analyze` après chaque module, typage strict, zéro `any` |
| §8 Base de données | Index sur toutes les FK, RLS policies, migrations versionnées |
| §13 Documentation | Ce design doc + task tracking dans docs/tasks/ |
| §14 Skills | brainstorming avant implémentation ✅, code-reviewer après chaque module |

---

## 10. Tests

| Type | Cible | Outil |
|---|---|---|
| Unitaires | Use-cases, entities, Failures | `flutter_test` + mocktail |
| Intégration | Repositories ↔ Datasources | Supabase local ou test container |
| Widget | Écrans (login, devices, license) | `flutter_test` |
| E2E | Parcours complet (signup → add device → sync) | Patrol ou integration_test |
| Sécurité | Auth, RLS, ownership, rate limiting | Scripts SQL + tests API |
| Charge | Sync concurrente (N devices simulés) | Script dédié |

---

## 11. Priorité d'implémentation

| Phase | Modules | Dépendances |
|---|---|---|
| **P1** | Core (constants, errors, DI), Domain (entities, repository interfaces) | Aucune |
| **P2** | Data (Supabase datasources, repository impls), Security (token, crypto) | P1 |
| **P3** | Auth (LoginUser, RegisterUser, LoginScreen, SignupScreen refactored) | P2 |
| **P4** | Devices (CRUD + ownership + MQTT), DeviceSyncScreen | P2 |
| **P5** | License (Subscription, License, UpgradeScreen, PremiumFeatureGate) | P2 |
| **P6** | Admin (UserManagement, LicenseManagement, DeviceManagement, Logs) | P2 |
| **P7** | Sync (RequestSync, Crypto UID handshake, SyncLog) | P2 + P4 |
| **P8** | Tests (unitaires → intégration → E2E) | Tout |
