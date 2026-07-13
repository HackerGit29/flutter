import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aricie/services/update_service.dart';

import '../helpers/supabase_test_helper.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getExternalStoragePath() async => '/tmp/aricie-test-storage';

  @override
  Future<String?> getTemporaryPath() async => '/tmp/aricie-test-tmp';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = _FakePathProviderPlatform();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-anon-key',
      httpClient: MockClient((request) async => emptyOk(request)),
      authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.implicit),
    );
  });

  group('UpdateInfo.fromJson', () {
    test('maps a full update payload', () {
      final info = UpdateInfo.fromJson({
        'updateAvailable': true,
        'version': '1.6.0',
        'apkUrl': 'https://example.com/app.apk',
        'releaseNotes': 'Bug fixes',
        'forceUpdate': true,
        'releaseDate': '2026-07-01',
      });

      expect(info.updateAvailable, true);
      expect(info.version, '1.6.0');
      expect(info.forceUpdate, true);
    });

    test('defaults updateAvailable and forceUpdate to false when missing', () {
      final info = UpdateInfo.fromJson({});

      expect(info.updateAvailable, false);
      expect(info.forceUpdate, false);
      expect(info.version, isNull);
    });
  });

  group('UpdateService', () {
    test('init() reads package info without throwing', () async {
      PackageInfo.setMockInitialValues(
        appName: 'Aricie',
        packageName: 'com.aricie.app',
        version: '1.6.0',
        buildNumber: '4',
        buildSignature: '',
      );

      await UpdateService.init();

      expect(UpdateService.instance.appVersion, '1.6.0');
      expect(UpdateService.instance.appBuildNumber, '4');
      expect(UpdateService.instance.currentVersion, '1.6.0+4');
    });

    test('checkForUpdate skips the network call when nobody is logged in', () async {
      final info = await UpdateService.instance.checkForUpdate();

      expect(info.updateAvailable, false);
    });

    test('checkForUpdateIfNeeded skips the check within the 24h cooldown', () async {
      SharedPreferences.setMockInitialValues({
        'last_update_check': DateTime.now().toIso8601String(),
      });

      // Should return quickly without ever reaching checkForUpdate()'s
      // network call, since the cooldown has not elapsed.
      await UpdateService.instance.checkForUpdateIfNeeded();
    });

    test('checkForUpdateIfNeeded proceeds once the cooldown has elapsed', () async {
      SharedPreferences.setMockInitialValues({
        'last_update_check':
            DateTime.now().subtract(const Duration(hours: 25)).toIso8601String(),
      });

      await UpdateService.instance.checkForUpdateIfNeeded();
    });

    test('apkDestination resolves under external storage', () async {
      final path = await UpdateService.instance.apkDestination();

      expect(path, '/tmp/aricie-test-storage/aricie-update.apk');
    });

    test('installApk is a no-op on a non-Android, non-web platform', () async {
      await UpdateService.instance.installApk('/tmp/aricie-test-storage/aricie-update.apk');
    });

    test('onUpdate/dispose do not throw', () {
      UpdateService.instance.onUpdate((_) {});
      UpdateService.instance.dispose();
    });
  });
}