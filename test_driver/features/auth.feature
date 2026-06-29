Feature: Authentication
  As a user
  I want to manage my account
  So that I can access my energy data securely

  Scenario: User registration
    Given I am on the registration screen
    When I enter a valid email and password
    And I submit the form
    Then I should be redirected to the home screen
    And a new user account should be created in Supabase

  Scenario: User login
    Given I have an existing account
    And I am on the login screen
    When I enter my correct credentials
    And I submit the form
    Then I should be logged in
    And my session should be stored securely

  Scenario: User logout
    Given I am currently logged in
    When I click the logout button
    Then I should be redirected to the login screen
    And my session should be cleared
