Feature: Unit Test Suite - Domain & Logic
  Compliance: ISO 25010 (Functional Suitability, Reliability)

  # Auth Logic
  Scenario: Validate user registration logic
    Given a user provides an email without '@'
    Then the RegistrationUseCase should return a Failure.validationError
    And no request should be sent to Supabase

  Scenario: Ensure secure logout clears local state
    Given a session exists in TokenManager
    When the LogoutUseCase is executed
    Then the TokenManager should be empty
    And the user state should be null

  # Device & Appliance Logic
  Scenario: Validate appliance toggle state transition
    Given an appliance with state 'off'
    When the ToggleDeviceUseCase is called
    Then the result should be 'on'
    And the command generated should be 'TURN_ON'

  Scenario: Ensure energy data aggregation is accurate
    Given a set of raw power readings [100, 200, 300]
    When the EnergyAggregator processes these readings
    Then the total consumption should be 600
    And the average should be 200

  # Admin Logic
  Scenario: Prevent non-admin from accessing admin use-cases
    Given a user with role 'user'
    When they attempt to call CreateBoxForUser
    Then the system should throw an UnauthorizedFailure
