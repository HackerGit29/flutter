Feature: Device Synchronization
  As a system
  I want to verify device identity and ownership
  So that only authorized boxes can communicate with the backend

  Scenario: Verifying device crypto UID
    Given a box sends a synchronization request with its crypto UID
    When the system validates the UID against the database
    Then the sync should be successful if the UID matches
    And a sync log should be created

  Scenario: Validating device ownership
    Given a device is attempting to sync
    When the system checks the owner_id of the device
    Then it should allow the sync only if the owner_id matches the requester's token
    And it should reject the request otherwise with an ownership error

  Scenario: Logging sync results
    Given a sync attempt is made
    When the sync completes (success or failure)
    Then a log entry should be added to 'sync_logs' with the result and timestamp
