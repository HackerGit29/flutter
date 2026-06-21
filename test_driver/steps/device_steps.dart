import 'package:flutter_gherkin/flutter_gherkin.dart';

class DeviceSteps extends GherkinSteps {
  @step('I am on the devices screen')
  void iAmOnTheDevicesScreen() {}

  @step('I add a new device with name {string}')
  void iAddANewDeviceWithName(String name) {}

  @step('I pair the device using its hardware UID')
  void iPairTheDeviceUsingItsHardwareUid() {}

  @step('the device status should change to "active"')
  void theDeviceStatusShouldChangeToActive() {}

  @step('I have an active device {string}')
  void iHaveAnActiveDevice(String name) {}

  @step('I toggle the device state to "off"')
  void iToggleTheDeviceStateToOff() {}

  @step('the device should receive an MQTT off command')
  void theDeviceShouldReceiveAnMqttOffCommand() {}
}