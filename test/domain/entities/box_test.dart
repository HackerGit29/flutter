import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/domain/entities/box.dart';

void main() {
  final kCreatedAt = DateTime(2026, 1, 1);

  final kBox = Box(
    id: 'box-1',
    uidHardware: 'ESP32-ABCDEF01',
    name: 'Boîtier Salon',
    location: 'Salon',
    userId: 'user-1',
    status: BoxStatus.active,
    createdAt: kCreatedAt,
  );

  group('Box — getters', () {
    test('isActive retourne true pour status active', () {
      expect(kBox.isActive, true);
      expect(kBox.isBlocked, false);
    });

    test('isBlocked retourne true pour status blocked', () {
      final blocked = kBox.copyWith(status: BoxStatus.blocked);
      expect(blocked.isBlocked, true);
      expect(blocked.isActive, false);
    });

    test('isActive retourne false pour status inactive', () {
      final inactive = kBox.copyWith(status: BoxStatus.inactive);
      expect(inactive.isActive, false);
      expect(inactive.isBlocked, false);
    });
  });

  group('Box — copyWith', () {
    test('copyWith met à jour le nom', () {
      final updated = kBox.copyWith(name: 'Nouveau nom');
      expect(updated.name, 'Nouveau nom');
      expect(updated.id, kBox.id);
      expect(updated.userId, kBox.userId);
    });

    test('copyWith met à jour le status', () {
      final updated = kBox.copyWith(status: BoxStatus.inactive);
      expect(updated.status, BoxStatus.inactive);
    });

    test('copyWith met à jour la location', () {
      final updated = kBox.copyWith(location: 'Cuisine');
      expect(updated.location, 'Cuisine');
    });

    test('copyWith met à jour le firmware', () {
      final updated = kBox.copyWith(firmwareVersion: '1.2.3');
      expect(updated.firmwareVersion, '1.2.3');
    });

    test('copyWith préserve les champs non modifiés', () {
      final updated = kBox.copyWith(name: 'Test');
      expect(updated.uidHardware, kBox.uidHardware);
      expect(updated.location, kBox.location);
      expect(updated.status, kBox.status);
      expect(updated.createdAt, kBox.createdAt);
    });
  });

  group('Box — fromJson', () {
    test('parse un JSON complet correctement', () {
      final json = {
        'id': 'box-1',
        'uid_hardware': 'ESP32-ABCDEF01',
        'name': 'Boîtier Salon',
        'location': 'Salon',
        'user_id': 'user-1',
        'status': 'active',
        'public_key': null,
        'last_sync': null,
        'firmware_version': '1.0.0',
        'created_at': '2026-01-01T00:00:00.000',
      };
      final box = Box.fromJson(json);
      expect(box.id, 'box-1');
      expect(box.uidHardware, 'ESP32-ABCDEF01');
      expect(box.name, 'Boîtier Salon');
      expect(box.status, BoxStatus.active);
      expect(box.firmwareVersion, '1.0.0');
    });

    test('parse status inactive correctement', () {
      final json = {
        'id': 'box-2', 'uid_hardware': '', 'name': 'Test',
        'user_id': 'user-1', 'status': 'inactive',
        'created_at': '2026-01-01T00:00:00.000',
      };
      final box = Box.fromJson(json);
      expect(box.status, BoxStatus.inactive);
    });

    test('parse status blocked correctement', () {
      final json = {
        'id': 'box-3', 'uid_hardware': 'ESP32-XYZ', 'name': 'Test',
        'user_id': 'user-1', 'status': 'blocked',
        'created_at': '2026-01-01T00:00:00.000',
      };
      final box = Box.fromJson(json);
      expect(box.status, BoxStatus.blocked);
    });

    test('uid_hardware absent → chaîne vide', () {
      final json = {
        'id': 'box-4', 'name': 'Test', 'user_id': 'user-1',
        'status': 'inactive', 'created_at': '2026-01-01T00:00:00.000',
      };
      final box = Box.fromJson(json);
      expect(box.uidHardware, '');
    });

    test('last_sync parsé correctement', () {
      final json = {
        'id': 'box-5', 'uid_hardware': 'ESP32-XYZ', 'name': 'Test',
        'user_id': 'user-1', 'status': 'active',
        'last_sync': '2026-06-01T12:00:00.000',
        'created_at': '2026-01-01T00:00:00.000',
      };
      final box = Box.fromJson(json);
      expect(box.lastSync, DateTime(2026, 6, 1, 12, 0, 0));
    });
  });

  group('Box — toJson', () {
    test('toJson produit les clés correctes', () {
      final json = kBox.toJson();
      expect(json['id'], 'box-1');
      expect(json['uid_hardware'], 'ESP32-ABCDEF01');
      expect(json['name'], 'Boîtier Salon');
      expect(json['user_id'], 'user-1');
      expect(json['status'], 'active');
    });

    test('toJson inclut location si défini', () {
      final json = kBox.toJson();
      expect(json['location'], 'Salon');
    });

    test('toJson omet location si null', () {
      final boxNoLocation = Box(
        id: 'box-x', uidHardware: 'ESP32-X', name: 'Test',
        userId: 'user-1', status: BoxStatus.active, createdAt: kCreatedAt,
      );
      final json = boxNoLocation.toJson();
      expect(json.containsKey('location'), false);
    });

    test('roundtrip fromJson → toJson préserve les données', () {
      final original = {
        'id': 'box-rt', 'uid_hardware': 'ESP32-RT', 'name': 'Roundtrip',
        'location': 'Bureau', 'user_id': 'user-rt', 'status': 'active',
        'public_key': null, 'last_sync': null, 'firmware_version': null,
        'created_at': '2026-01-01T00:00:00.000',
      };
      final box = Box.fromJson(original);
      final json = box.toJson();
      expect(json['id'], original['id']);
      expect(json['uid_hardware'], original['uid_hardware']);
      expect(json['status'], original['status']);
    });
  });
}
