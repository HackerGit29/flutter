import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/domain/entities/license.dart';

void main() {
  group('License Entity', () {
    final activationDate = DateTime.now().subtract(const Duration(days: 1));
    final expirationDate = DateTime.now().add(const Duration(days: 1));

    test('fromJson parses correctly with expiration date', () {
      final json = {
        'id': 'lic-123',
        'subscription_id': 'sub-456',
        'activation_date': activationDate.toIso8601String(),
        'expiration_date': expirationDate.toIso8601String(),
        'license_key': 'KEY-123',
      };

      final license = License.fromJson(json);

      expect(license.id, 'lic-123');
      expect(license.subscriptionId, 'sub-456');
      expect(license.activationDate, isNotNull);
      expect(license.expirationDate, isNotNull);
      expect(license.licenseKey, 'KEY-123');
    });

    test('fromJson parses correctly with null expiration date', () {
      final json = {
        'id': 'lic-123',
        'subscription_id': 'sub-456',
        'activation_date': activationDate.toIso8601String(),
        'expiration_date': null,
        'license_key': 'KEY-123',
      };

      final license = License.fromJson(json);

      expect(license.expirationDate, isNull);
    });

    test('isValid returns true when active and not expired', () {
      final license = License(
        id: 'lic-123',
        subscriptionId: 'sub-456',
        activationDate: activationDate,
        expirationDate: expirationDate,
        licenseKey: 'KEY-123',
      );

      expect(license.isValid, isTrue);
    });

    test('isValid returns true when active and expiration date is null', () {
      final license = License(
        id: 'lic-123',
        subscriptionId: 'sub-456',
        activationDate: activationDate,
        expirationDate: null,
        licenseKey: 'KEY-123',
      );

      expect(license.isValid, isTrue);
    });

    test('isValid returns false when now is before activation date', () {
      final futureActivation = DateTime.now().add(const Duration(days: 1));
      final license = License(
        id: 'lic-123',
        subscriptionId: 'sub-456',
        activationDate: futureActivation,
        expirationDate: futureActivation.add(const Duration(days: 1)),
        licenseKey: 'KEY-123',
      );

      expect(license.isValid, isFalse);
    });

    test('isValid returns false when expired', () {
      final pastExpiration = DateTime.now().subtract(const Duration(hours: 1));
      final license = License(
        id: 'lic-123',
        subscriptionId: 'sub-456',
        activationDate: pastExpiration.subtract(const Duration(days: 1)),
        expirationDate: pastExpiration,
        licenseKey: 'KEY-123',
      );

      expect(license.isValid, isFalse);
    });
  });
}
