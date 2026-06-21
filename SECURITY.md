# Security Policy — aricie

This document defines the security standards and requirements for all agents and developers working on the aricie project.

## 🛡️ Security Standards (OMT_2024_v2)

All implementations must adhere to the following mitigations:

### 1. Communication & Transport (M5)
- **Requirement**: ALL external communication must be encrypted (TLS/SSL).
- **Action**: Use `wss://` or `https://`. No cleartext MQTT on public brokers.
- **Check**: Verify `MqttService` uses secure endpoints.

### 2. Cryptography & Identity (M10)
- **Requirement**: Device identification must use asymmetric signing (ECDSA/Ed25519).
- **Action**: Do NOT use simple SHA256 hashes for signatures.
- **Check**: Implement challenge-response with private key signing on device and public key verification on backend.

### 3. Data Storage (M9)
- **Requirement**: Sensitive user data (tokens, IDs, PII) must be stored in secure hardware-backed storage.
- **Action**: Use `flutter_secure_storage`. Do NOT use `shared_preferences` for sensitive data.
- **Check**: Audit all storage calls.

### 4. Credential Management (M1)
- **Requirement**: No secrets in source code.
- **Action**: Use `.env` files and ensure they are in `.gitignore`.
- **Check**: Audit `main.dart` and services for hardcoded keys.

### 5. Binary Protection (M7)
- **Requirement**: Production builds must be obfuscated.
- **Action**: Always use `--obfuscate` and `--split-debug-info` during release builds.
- **Build Command**: `fvm flutter build apk --obfuscate --split-debug-info=build/obfuscation/`

### 6. Input Validation (M4)
- **Requirement**: All trust boundaries (User Input $\rightarrow$ Backend) must be validated.
- **Action**: Use strict typing and validation logic in UI forms and API controllers.

---

## 🚩 Audit History
- **2026-06-21**: Initial OMT_2024_v2 audit performed. Critical risks in MQTT (cleartext) and DeviceCrypto (naive hashing) identified and mitigated (infrastructure added).
