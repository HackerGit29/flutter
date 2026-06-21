import 'package:flutter_gherkin/flutter_gherkin.dart';

class UserSteps extends GherkinSteps {
  @step('I am on the login screen')
  void iAmOnTheLoginScreen() {}

  @step('I enter valid credentials')
  void iEnterValidCredentials() {}

  @step('I click the login button')
  void iClickTheLoginButton() {}

  @step('I should be redirected to the home screen')
  void iShouldBeRedirectedToTheHomeScreen() {}

  @step('I am on the signup screen')
  void iAmOnTheSignupScreen() {}

  @step('I enter a new email and password')
  void iEnterANewEmailAndPassword() {}

  @step('I click the register button')
  void iClickTheRegisterButton() {}

  @step('I should have a new account and be redirected to the home screen')
  void iShouldHaveANewAccountAndBeRedirectedToTheHomeScreen() {}
}