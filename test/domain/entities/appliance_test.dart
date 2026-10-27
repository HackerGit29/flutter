import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/domain/entities/appliance.dart';

void main() {
  final kCreatedAt = DateTime(2026, 1, 1);

  final kAppliance = Appliance(
    id: 'app-1',
    boxId: 'box-1',
    boxUid: 'ESP32-ABCDEF01',
    userId: 'user-1',
    relayIndex: 1,
    name: 'Chauffe-eau',
    location: 'Salle de bain',
    isOn: false,
    createdAt: kCreatedAt,
  );

  group('Appliance — copyWith', () {
    test('copyWith met à jour le nom', () {
      final updated = kAppliance.copyWith(name: 'Nouveau nom');
      expect(updated.name, 'Nouveau nom');
      expect(updated.id, kAppliance.id);
      expect(updated.relayIndex, kAppliance.relayIndex);
    });

    test('copyWith met à jour isOn', () {
      final on = kAppliance.copyWith(isOn: true);
      expect(on.isOn, true);
      final off = on.copyWith(isOn: false);
      expect(off.isOn, false);
    });

    test('copyWith met à jour location', () {
      final updated = kAppliance.copyWith(location: 'Cuisine');
      expect(updated.location, 'Cuisine');
    });

    test('copyWith met à jour boxUid', () {
      final updated = kAppliance.copyWith(boxUid: 'ESP32-NEW');
      expect(updated.boxUid, 'ESP32-NEW');
    });

    test('copyWith préserve les champs non modifiés', () {
      final updated = kAppliance.copyWith(name: 'Test');
      expect(updated.boxId, kAppliance.boxId);
      expect(updated.userId, kAppliance.userId);
      expect(updated.isOn, kAppliance.isOn);
      expect(updated.createdAt, kAppliance.createdAt);
    });
  });

  group('Appliance — fromJson', () {
    test('parse un JSON complet correctement', () {
      final json = {
        'id': 'app-1',
        'box_id': 'box-1',
        'box_uid': 'ESP32-ABCDEF01',
        'user_id': 'user-1',
        'relay_index': 1,
        'name': 'Chauffe-eau',
        'location': 'Salle de bain',
        'is_on': false,
        'created_at': '2026-01-01T00:00:00.000',
      };
      final appliance = Appliance.fromJson(json);
      expect(appliance.id, 'app-1');
      expect(appliance.boxId, 'box-1');
      expect(appliance.relayIndex, 1);
      expect(appliance.name, 'Chauffe-eau');
      expect(appliance.isOn, false);
    });

    test('is_on absent → false par défaut', () {
      final json = {
        'id': 'app-2', 'box_id': 'box-1', 'user_id': 'user-1',
        'relay_index': 2, 'name': 'Lampe',
        'created_at': '2026-01-01T00:00:00.000',
      };
      final appliance = Appliance.fromJson(json);
      expect(appliance.isOn, false);
    });

    test('is_on true parsé correctement', () {
      final json = {
        'id': 'app-3', 'box_id': 'box-1', 'user_id': 'user-1',
        'relay_index': 3, 'name': 'Climatiseur', 'is_on': true,
        'created_at': '2026-01-01T00:00:00.000',
      };
      final appliance = Appliance.fromJson(json);
      expect(appliance.isOn, true);
    });

    test('box_uid absent → null', () {
      final json = {
        'id': 'app-4', 'box_id': 'box-1', 'user_id': 'user-1',
        'relay_index': 1, 'name': 'Test',
        'created_at': '2026-01-01T00:00:00.000',
      };
      final appliance = Appliance.fromJson(json);
      expect(appliance.boxUid, null);
    });

    test('location absent → null', () {
      final json = {
        'id': 'app-5', 'box_id': 'box-1', 'user_id': 'user-1',
        'relay_index': 1, 'name': 'Test',
        'created_at': '2026-01-01T00:00:00.000',
      };
      final appliance = Appliance.fromJson(json);
      expect(appliance.location, null);
    });
  });

  group('Appliance — toJson', () {
    test('toJson produit les clés correctes', () {
      final json = kAppliance.toJson();
      expect(json['id'], 'app-1');
      expect(json['box_id'], 'box-1');
      expect(json['user_id'], 'user-1');
      expect(json['relay_index'], 1);
      expect(json['name'], 'Chauffe-eau');
      expect(json['is_on'], false);
    });

    test('toJson inclut box_uid si défini', () {
      final json = kAppliance.toJson();
      expect(json['box_uid'], 'ESP32-ABCDEF01');
    });

    test('toJson omet box_uid si null', () {
      final appNoUid = Appliance(
        id: 'app-x', boxId: 'box-1', userId: 'user-1',
        relayIndex: 1, name: 'Test', createdAt: kCreatedAt,
      );
      final json = appNoUid.toJson();
      expect(json.containsKey('box_uid'), false);
    });

    test('toJson inclut location si défini', () {
      final json = kAppliance.toJson();
      expect(json['location'], 'Salle de bain');
    });

    test('toJson omet location si null', () {
      final appNoLoc = Appliance(
        id: 'app-y', boxId: 'box-1', userId: 'user-1',
        relayIndex: 2, name: 'Test', createdAt: kCreatedAt,
      );
      final json = appNoLoc.toJson();
      expect(json.containsKey('location'), false);
    });

    test('roundtrip fromJson → toJson préserve les données', () {
      final original = {
        'id': 'app-rt', 'box_id': 'box-rt', 'box_uid': 'ESP32-RT',
        'user_id': 'user-rt', 'relay_index': 2, 'name': 'Roundtrip',
        'location': 'Bureau', 'is_on': true,
        'created_at': '2026-06-01T00:00:00.000',
      };
      final appliance = Appliance.fromJson(original);
      final json = appliance.toJson();
      expect(json['id'], original['id']);
      expect(json['relay_index'], original['relay_index']);
      expect(json['is_on'], original['is_on']);
    });
  });
}
