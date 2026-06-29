Feature: Device Management
  As a user
  I want to manage my energy boxes and appliances
  So that I can monitor and control my home energy

  Scenario: Pairing a new box
    Given I have a box hardware UID
    When I enter the UID in the pairing screen
    And I confirm the pairing
    Then the box should be linked to my account
    And the box should appear in my devices list

  Scenario: Toggling an appliance
    Given I have a paired box with a "Water Heater" appliance
    When I toggle the state of the "Water Heater"
    Then a command should be written to 'device_commands' table
    And the appliance state should update in the UI
    And the MQTT worker should publish the command to the box

  Scenario: Renaming an appliance
    Given I have an appliance named "Generic Relay 1"
    When I rename it to "Living Room Light"
    Then the appliance name should be updated in the database
    And the new name should be reflected in the UI

  Scenario: Viewing real-time energy data
    Given my box is sending telemetry
    When I open the statistics screen
    Then I should see the live consumption indicator updating
    And the data should match the MQTT telemetry stream
