Feature: MQTT Communication
  As a system
  I want to exchange telemetry and commands with physical boxes
  So that the app and backend stay synchronized with the hardware

  Scenario: App connecting to broker
    Given the app has a valid boxUid
    When the MqttService initializes
    Then it should connect to 'mqtt.flespi.io' via WSS/TCP
    And it should subscribe to the telemetry topic for that boxUid

  Scenario: Receiving telemetry data
    Given a box publishes telemetry to 'aricie/v1/boxes/[uid]/telemetry'
    When the app is connected
    Then the LiveConsumptionIndicator should update in real-time
    And the telemetry data should be parsed correctly

  Scenario: Worker processing command queue
    Given a command is in 'pending' state in 'device_commands'
    When the MQTT Worker detects the pending command
    Then it should publish the command to the box's MQTT topic
    And it should update the command status to 'sent'

  Scenario: Handling Command ACK
    Given a box receives a command and publishes an ACK
    When the MQTT Worker receives the ACK on the ACK topic
    Then it should update the corresponding command status to 'success' in the DB
