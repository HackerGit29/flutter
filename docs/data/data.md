# Data Layer

Implements the domain repositories and manages data sources.

## Datasources
- `SupabaseAuthDatasource`: Wraps Supabase Auth API. Uses `maybeSingle()` for profile loading (avoids overwriting role on transient errors). Profile creation via `insert().select().single()` to ensure `created_at` is returned. Password reset flow: `resetPassword()` envoie un code OTP par email, `verifyRecoveryOtp()` valide le code, `updatePassword()` met à jour le mot de passe après validation.
- `SupabaseBoxDatasource`: Manages box records in PostgreSQL (table `boxes`).
- `SupabaseApplianceDatasource`: Manages appliance relay records (table `appliances`). Joins `boxes` to populate `box_uid` on `getUserAppliances`. `toggleAppliance()` writes a `device_commands` row (`pending`, `user_toggle`) before the optimistic `appliances.update`.
- `SupabaseEnergyDatasource`: Queries aggregated energy consumption (table `energy_data`).
- `SupabaseLicenseDatasource`: Handles subscription and license queries.
- `SupabaseSyncDatasource`: Logs sync events and retrieves telemetry.
- `SupabaseAdminDatasource`: Privileged operations for system admin. `createBox()` inserts a box; `createAppliancesForBox()` inserts 3 appliances (relay_index 1..3) for a box, with admin check and `admin_actions` logging.
- `LocalDatasource`: Local cache and persistence.

## Repository Implementations
Concrete implementations of domain repositories that orchestrate datasources.
- `AuthRepositoryImpl`
- `BoxRepositoryImpl`
- `ApplianceRepositoryImpl`
- `EnergyRepositoryImpl`
- `LicenseRepositoryImpl`
- `SyncRepositoryImpl`
- `AdminRepositoryImpl`
