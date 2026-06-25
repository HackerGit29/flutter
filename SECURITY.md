# Security Policy — aricie

This document defines the security standards and requirements for all contributors and maintainers of the aricie project.

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x     | ✅ Active |

## Reporting a Vulnerability

To report a security vulnerability, please open an issue with the `security` label or contact the maintainers directly. Do **not** disclose security vulnerabilities publicly via issues or discussions.

We aim to acknowledge reports within 48 hours and provide a timeline for resolution.

## Security Standards (OMT_2024_v2)

All implementations must adhere to the following mitigations:

### 1. Communication & Transport (M5)

- **Requirement**: All external communication must be encrypted (TLS/SSL).
- **Action**: Use `wss://` or `https://`. No cleartext MQTT on public brokers.
- **Check**: Verify `MqttService` uses secure endpoints (`wss://127.0.0.1:8883`).
- **Status**: ✅ Production broker uses WSS/TLS. Development (`test.mosquitto.org`) is cleartext — do not use with real data.

### 2. Cryptography & Identity (M10)

- **Requirement**: Device identification must use asymmetric signing (ECDSA/Ed25519).
- **Action**: Do **not** use simple SHA-256 hashes for signatures. Implement challenge-response with private key signing on device and public key verification on backend.
- **Check**: Verify `DeviceCrypto` in `lib/core/security/` uses ECDSA. Audit all signature verification logic.
- **Status**: ✅ Challenge-response infrastructure added (see `docs/core/core.md`).

### 3. Data Storage (M9)

- **Requirement**: Sensitive user data (tokens, IDs, PII) must be stored in secure hardware-backed storage.
- **Action**: Use `flutter_secure_storage`. Do **not** use `SharedPreferences` for tokens, sessions, or PII.
- **Check**: Audit all storage calls — `TokenManager` must use `FlutterSecureStorage`. Local session caching via `SharedPreferences` is acceptable for non-sensitive data only (see `LocalDataSource`).
- **Status**: ✅ Tokens migrated to secure storage. Session cache uses `SharedPreferences` (cached user ID only).

### 4. Credential Management (M1)

- **Requirement**: No secrets in source code.
- **Action**: Use `--dart-define` at compile time or `.env` files. Ensure `.env` is in `.gitignore`.
- **Check**: Audit `main.dart`, `constants.dart`, and all service files for hardcoded keys.
- **Status**: ✅ `SUPABASE_URL` and `SUPABASE_ANON_KEY` are passed via `--dart-define`.

### 5. Binary Protection (M7)

- **Requirement**: Production builds must be obfuscated.
- **Action**: Always use `--obfuscate` and `--split-debug-info` during release builds.
- **Command**: `flutter build apk --obfuscate --split-debug-info=build/obfuscation/`
- **Check**: Verify build scripts include these flags. Ensure debug symbols are not distributed.
- **Status**: ✅ Build command documented in `AGENTS.md`.

### 6. Input Validation (M4)

- **Requirement**: All trust boundaries (User Input → Backend) must be validated.
- **Action**: Use strict typing, form validation, and sanitization in UI forms and API controllers.
- **Check**: Audit form submissions for injection risks. Verify Supabase RLS policies enforce ownership.
- **Status**: 🟡 In progress — basic validation present, comprehensive audit pending.

### 7. Access Control (M2)

- **Requirement**: Role-based access control (RBAC) with strict perimeter separation.
- **Action**: Enforce `user_id` ownership on all database queries. Admin bypass via `private.is_admin()` SECURITY DEFINER function (queries `public.users.role`, not JWT claims).
- **Check**: Verify RLS policies on all tables. Audit use-cases for permission checks.
- **Status**: ✅ RLS policies defined in `docs/supabase/init_db.sql`. Admin use-cases include RBAC checks.

### 8. Rate Limiting (M6)

- **Requirement**: API abuse prevention for sync and admin operations.
- **Action**: Implement rate limiting per user and per device.
- **Limits**: 10 syncs/minute per device, 5 admin actions/minute.
- **Status**: ✅ `RateLimiter` implemented in `lib/core/security/`.

## Audit Trail

All administrative actions are logged in the `admin_actions` table with:
- Admin identity (`admin_id`)
- Action type and target
- Timestamp and context (`details` JSONB)
- IP address for sync operations

## Compliance

This project follows the OMT_2024_v2 mobile threat model framework. Regular security audits are performed to ensure ongoing compliance.

## Audit History

| Date | Type | Scope | Findings |
|------|------|-------|----------|
| 2026-06-21 | Initial | OMT_2024_v2 full audit | Critical risks in MQTT (cleartext) and DeviceCrypto (naive hashing) identified and mitigated. Infrastructure added for challenge-response and secure MQTT. |
