Feature: Data Synchronization
  As a device
  I want to synchronize my measurements
  So that the user can see them in the app

  Scenario: Successful Sync
    Given a paired device with a valid session
    When the device requests a synchronization
    And it provides a valid crypto signature
    Then the data should be stored in Supabase
    And a "success" sync log should be created
