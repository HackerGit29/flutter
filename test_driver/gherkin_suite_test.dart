import 'package:flutter_gherkin/flutter_gherkin.dart';
import 'package:gherkin/gherkin.dart';
import 'steps/user_steps.dart';
import 'steps/device_steps.dart';

Future<void> main() {
  final config = FlutterTestConfiguration()
    ..features = [RegExp(r"test_driver/features/*\.feature")]
    ..reporters = [ProgressReporter()]
    ..stepDefinitions = [
      UserSteps(),
      DeviceSteps(),
    ]
    ..restartAppBetweenScenarios = true;

  return GherkinRunner().execute(config);
}