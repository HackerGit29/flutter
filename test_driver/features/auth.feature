Feature: Authentication
  As a user
  I want to manage my account
  So that I can access my energy data

  Scenario: Successful Login
    Given I am on the login screen
    When I enter valid credentials
    And I click the login button
    Then I should be redirected to the home screen

  Scenario: User Registration
    Given I am on the signup screen
    When I enter a new email and password
    And I click the register button
    Then I should have a new account and be redirected to the home screen
