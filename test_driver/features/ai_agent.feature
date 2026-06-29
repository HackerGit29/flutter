Feature: AI Agent Orchestrator
  As a user
  I want to interact with my home via a natural language agent
  So that I can control devices and get energy insights easily

  Scenario: Chatting with the agent
    Given I am in the chatbot screen
    When I send a message "Hello, how much energy did I use today?"
    Then I should receive a streamed response via SSE
    And the response should include actual energy data from the DB

  Scenario: Controlling a device via chat
    Given I have a "Water Heater" appliance
    When I tell the agent "Turn off the water heater"
    Then the agent should trigger the 'toggle_device' tool
    And a command should be created in 'device_commands'
    And the agent should confirm the action in the chat

  Scenario: Voice interaction (STT and TTS)
    Given I have voice mode enabled
    When I speak a command "Turn on the lights"
    Then the audio should be transcribed via Azure STT
    And the agent should process the text command
    And the response should be spoken back via Azure Neural TTS
