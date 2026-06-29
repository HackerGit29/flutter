Feature: E2E Test Suite - User Journeys
  Compliance: ISO 25010 (Usability, Performance Efficiency)

  # Journey 1: First Time Setup
  Scenario: Onboarding to first device control
    Given a new user has just registered
    And they have a box hardware UID
    When they complete the pairing flow
    And they navigate to the devices screen
    And they toggle their first appliance
    Then the appliance status should change to 'ON' within 2 seconds
    And the success toast should appear

  # Journey 2: AI Energy Management
  Scenario: Querying energy stats via Voice
    Given the user is on the Home screen
    And the device is connected via MQTT
    When the user activates voice mode
    And says "Quelle était ma consommation hier ?"
    Then the agent should retrieve data from energy_data table
    And the voice response should announce the correct value
    And the UI should highlight the relevant chart

  # Journey 3: Admin Provisioning
  Scenario: Admin sets up a user's home
    Given an admin is logged in
    When they create a new box for user 'U123'
    And they generate the default 3 appliances
    And they log out
    And user 'U123' logs in
    Then user 'U123' should see the pre-configured box in their list
