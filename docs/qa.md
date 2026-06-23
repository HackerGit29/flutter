# Quality Assurance (QA)

This project follows a Test-Driven Development (TDD) approach integrated with BDD.

## BDD Framework (Cucumber/Gherkin)
The project uses `flutter_gherkin` to define behavior-driven scenarios.

### Structure
- `test_driver/app.dart`: Entry point for driver tests.
- `test_driver/features/*.feature`: Gherkin scenarios for business requirements.
- `test_driver/steps/*.dart`: Step definitions mapping Gherkin phrases to code logic.

### Running Tests
- **Driver**: `flutter drive --target=test_driver/app.dart`
- **Runner**: `dart test_driver/gherkin_suite_test.dart`

## Static Analysis & Code Quality
- **Flutter Analyze**: Standard linting using `flutter_lints`.
- **SonarQube**: Automated quality gate and security scanning.
  - Project Key: `aricie`
  - Scanner: `sonar-scanner`
  - Target: `lib/` source and `test_driver/` tests.
