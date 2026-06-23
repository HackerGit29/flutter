# Data Layer

Implements the domain repositories and manages data sources.

## Datasources
- `SupabaseAuthDatasource`: Wraps Supabase Auth API.
- `SupabaseBoxDatasource`: Manages box records in PostgreSQL (table `boxes`).
- `SupabaseApplianceDatasource`: Manages appliance relay records (table `appliances`). Joins `boxes` to populate `box_uid` on `getUserAppliances`.
- `SupabaseEnergyDatasource`: Queries aggregated energy consumption (table `energy_data`).
- `SupabaseLicenseDatasource`: Handles subscription and license queries.
- `SupabaseSyncDatasource`: Logs sync events and retrieves telemetry.
- `SupabaseAdminDatasource`: Privileged operations for system admin.
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
