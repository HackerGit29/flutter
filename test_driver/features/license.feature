Feature: License and Subscription
  As a user
  I want to manage my subscription and product keys
  So that I can access premium features

  Scenario: Redeeming a product key
    Given I have a valid product key
    When I enter the key in the license screen
    Then my account should be upgraded to the corresponding plan
    And the product key should be marked as used

  Scenario: Checking license validity
    Given I have an active subscription
    When I access a premium feature
    Then the system should allow access
    And the license check should return 'valid'

  Scenario: Upgrading to VIP plan
    Given I am on the subscription plan
    When I choose to upgrade to VIP
    Then my subscription status should change to 'vip'
    And I should have access to all advanced AI features

  Scenario: Cancelling subscription
    Given I have a recurring subscription
    When I cancel my subscription
    Then my account should keep access until the end of the billing period
    And the subscription should be marked for non-renewal
