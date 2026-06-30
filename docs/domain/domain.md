# Domain Layer

Defines the business logic, entities, and repository interfaces.

## Entities
- `User`: User profile, role (Admin/User/VIP), and status.
- `Box`: Physical IoT box with hardware UID, firmware version, public key, and connection status.
- `Appliance`: Relay channel (1..3 per Box) with name, location, on/off state, and `boxUid` (hardware UID, populated via join with `boxes`).
- `EnergyData`: Per-appliance energy consumption aggregated by day/week/month/year.
- `Subscription`: Subscription type (Free/VIP) and validity dates.
- `License`: License keys linked to subscriptions.
- `SyncLog`: Record of box synchronization events (JSONB payload as source of truth).
- `AdminAction`: Audit log for administrative changes with typed actions and targets.

## Repositories (Interfaces)
- `AuthRepository`: User authentication, session, password reset (OTP recovery).
- `BoxRepository`: CRUD, pairing, and status for boxes.
- `ApplianceRepository`: CRUD and state management for appliances.
- `EnergyRepository`: Aggregated energy consumption queries.
- `LicenseRepository`: Subscription and license management.
- `SyncRepository`: Box synchronization orchestration.
- `AdminRepository`: System-wide administrative operations.

## Use Cases
- **Auth**: Login, Register, Logout, GetCurrentUser, ResetPassword (envoi code OTP par email), ConfirmPasswordReset (validation code OTP + nouveau mot de passe).
- **Boxes**: GetUserBoxes (lecture seule — l'utilisateur n'ajoute plus de boîtier).
- **Appliances**: GetUserAppliances, ToggleAppliance (écrit dans `device_commands` + optimiste `appliances.update`), RenameAppliance.
- **Energy**: GetEnergyHistory, GetEnergyByAppliance.
- **License**: GetSubscription, UpgradeToVip, Cancel, CheckValidity.
- **Sync**: RequestSync, ValidateOwnership, VerifyCrypto, LogResult.
- **Admin**: SuspendUser, ActivateUser, AssignRole, GetAllBoxes, ResetBox, AssignBox, ForceSync, **CreateBoxForUser**, **CreateAppliancesForBox**.
