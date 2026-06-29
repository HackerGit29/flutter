Feature: Security Test Suite - OWASP Mobile Top 10 2024
  Compliance: ISO 25010 (Security), OWASP Mobile 2024

  # M1: Improper Platform Usage
  Scenario: Verify secure storage for JWT
    Given a user is authenticated
    Then the JWT must be stored in 'flutter_secure_storage' (Encrypted)
    And NOT in 'shared_preferences' (Plaintext)

  # M2: Insecure Data Storage
  Scenario: Check for sensitive data in logs
    When the app performs a network request
    Then the log output must NOT contain the Supabase Anon Key or User JWT
    And no sensitive PII should be written to the device filesystem

  # M3: Insecure Communication
  Scenario: Enforce TLS for MQTT and API
    Given a connection attempt to the broker or Supabase
    Then the protocol must be 'mqtts://' or 'https://'
    And the connection must fail if the server certificate is invalid

  # M4: Insecure Authentication/Authorization
  Scenario: Validate RLS on energy data
    Given user A and user B
    When user A attempts to fetch energy_data where owner_id = user_B_id
    Then the Supabase RLS policy must reject the request (403 Forbidden)

  # M5: Insufficient Privacy Controls
  Scenario: Validate notification permission handling
    Given the app requests push notification permission
    When the user denies the permission
    Then the app must continue to function without crashing
    And it should not attempt to bypass the OS permission dialog

  # M8: Insufficient Binary Protection
  Scenario: Verify obfuscation during release build
    Given a release APK is generated
    When analyzing the binary with a decompiler
    Then class and method names must be obfuscated (e.g., a, b, c)
    And strings like 'SUPABASE_URL' should not be easily extractable in plaintext
