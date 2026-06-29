Feature: Administrative Management
  As an administrator
  I want to manage the entire system infrastructure
  So that I can provision users and devices and monitor health

  Scenario: Provisioning a new box for a user
    Given I am logged in as an admin
    And I have a target user and a hardware UID
    When I create a new box for that user
    Then the box should be created with the correct owner_id
    And the box should be available for the user to pair

  Scenario: Creating appliances for a box
    Given a box exists in the system
    When I trigger the "Create 3 Appliances" action for that box
    Then 3 appliances should be created and linked to the box
    And they should be categorized correctly

  Scenario: Suspending a user
    Given a user account exists
    When I suspend the user from the admin dashboard
    Then the user's role should be updated to 'suspended'
    And the user should be unable to authenticate

  Scenario: Monitoring device commands
    Given commands are being sent to boxes
    When I view the command logs in the admin panel
    Then I should see all pending, sent, and failed commands
    And be able to filter by device UID
