Feature: Device Management
  As a user
  I want to manage my IoT devices
  So that I can monitor my energy consumption

  Scenario: Adding and Pairing a Device
    Given I am on the devices screen
    When I add a new device with name "Living Room"
    And I pair the device using its hardware UID
    Then the device status should change to "active"

  Scenario: Toggling Device State
    Given I have an active device "Living Room"
    When I toggle the device state to "off"
    Then the device should receive an MQTT off command
