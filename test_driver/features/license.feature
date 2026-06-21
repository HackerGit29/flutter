Feature: License and VIP
  As a user
  I want to upgrade my account to VIP
  So that I can access premium features

  Scenario: VIP Upgrade
    Given I have a "free" subscription
    When I upgrade to VIP using a valid license key
    Then my subscription type should become "vip"
    And I should have access to extended historical data
