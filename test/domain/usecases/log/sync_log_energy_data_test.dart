import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:aricie/domain/entities/energy_data.dart';

void main() {
  // ─── SyncLog ──────────────────────────────────────────────────────────────
  group('SyncLog — fromJson', () {
    test('parse status success correctement', () {
      final json = {
        'id': 's1', 'box_id': 'box-1', 'user_id': 'user-1',
        'status': 'success', 'data': {'packets': 10},
        'error_message': null, 'ip_address': '192.168.1.1',
        'timestamp': '2026-06-26T12:00:00.000',
      };
      final log = SyncLog.fromJson(json);
      expect(log.id, 's1');
      expect(log.status, SyncStatus.success);
      expect(log.data, {'packets': 10});
      expect(log.ipAddress, '192.168.1.1');
    });

    test('parse status failed correctement', () {
      final json = {
        'id': 's2', 'box_id': 'box-1', 'user_id': 'user-1',
        'status': 'failed', 'error_message': 'Timeout',
        'timestamp': '2026-06-26T12:00:00.000',
      };
      final log = SyncLog.fromJson(json);
      expect(log.status, SyncStatus.failed);
      expect(log.errorMessage, 'Timeout');
    });

    test('parse status unauthorized correctement', () {
      final json = {
        'id': 's3', 'box_id': 'box-1', 'user_id': 'user-1',
        'status': 'unauthorized', 'timestamp': '2026-06-26T12:00:00.000',
      };
      final log = SyncLog.fromJson(json);
      expect(log.status, SyncStatus.unauthorized);
    });

    test('parse status crypto_mismatch correctement', () {
      final json = {
        'id': 's4', 'box_id': 'box-1', 'user_id': 'user-1',
        'status': 'crypto_mismatch', 'timestamp': '2026-06-26T12:00:00.000',
      };
      final log = SyncLog.fromJson(json);
      expect(log.status, SyncStatus.cryptoMismatch);
    });

    test('parse status device_blocked correctement', () {
      final json = {
        'id': 's5', 'box_id': 'box-1', 'user_id': 'user-1',
        'status': 'device_blocked', 'timestamp': '2026-06-26T12:00:00.000',
      };
      final log = SyncLog.fromJson(json);
      expect(log.status, SyncStatus.deviceBlocked);
    });

    test('champs optionnels absents → null', () {
      final json = {
        'id': 's6', 'box_id': 'box-1', 'user_id': 'user-1',
        'status': 'success', 'timestamp': '2026-06-26T12:00:00.000',
      };
      final log = SyncLog.fromJson(json);
      expect(log.data, null);
      expect(log.errorMessage, null);
      expect(log.ipAddress, null);
    });
  });

  group('SyncLog — toJson', () {
    final kLog = SyncLog(
      id: 's1', boxId: 'box-1', userId: 'user-1',
      status: SyncStatus.success,
      data: {'packets': 5},
      errorMessage: null, ipAddress: '10.0.0.1',
      timestamp: DateTime(2026, 6, 26, 12, 0, 0),
    );

    test('toJson produit les clés correctes', () {
      final json = kLog.toJson();
      expect(json['id'], 's1');
      expect(json['box_id'], 'box-1');
      expect(json['user_id'], 'user-1');
      expect(json['status'], 'success');
      expect(json['ip_address'], '10.0.0.1');
    });

    test('toJson convertit crypto_mismatch vers le format DB', () {
      final log = SyncLog(
        id: 'x', boxId: 'b', userId: 'u',
        status: SyncStatus.cryptoMismatch,
        timestamp: DateTime(2026, 1, 1),
      );
      expect(log.toJson()['status'], 'crypto_mismatch');
    });

    test('toJson convertit device_blocked vers le format DB', () {
      final log = SyncLog(
        id: 'x', boxId: 'b', userId: 'u',
        status: SyncStatus.deviceBlocked,
        timestamp: DateTime(2026, 1, 1),
      );
      expect(log.toJson()['status'], 'device_blocked');
    });

    test('toJson convertit failed correctement', () {
      final log = SyncLog(
        id: 'x', boxId: 'b', userId: 'u',
        status: SyncStatus.failed,
        timestamp: DateTime(2026, 1, 1),
      );
      expect(log.toJson()['status'], 'failed');
    });

    test('roundtrip fromJson → toJson préserve les données', () {
      final original = {
        'id': 'rt', 'box_id': 'box-rt', 'user_id': 'user-rt',
        'status': 'success', 'data': null, 'error_message': null,
        'ip_address': null, 'timestamp': '2026-06-26T12:00:00.000',
      };
      final log = SyncLog.fromJson(original);
      final json = log.toJson();
      expect(json['id'], original['id']);
      expect(json['status'], original['status']);
    });
  });

  // ─── EnergyData ───────────────────────────────────────────────────────────
  group('EnergyData — fromJson', () {
    test('parse un JSON complet correctement', () {
      final json = {
        'id': 'e1', 'user_id': 'user-1', 'appliance_id': 'app-1',
        'date': '2026-06-01T00:00:00.000',
        'kwh': 2.5, 'cumulative_kwh': 15.3,
        'week': 22, 'month': 6, 'year': 2026,
        'created_at': '2026-06-01T00:00:00.000',
      };
      final data = EnergyData.fromJson(json);
      expect(data.id, 'e1');
      expect(data.kwh, 2.5);
      expect(data.cumulativeKwh, 15.3);
      expect(data.week, 22);
      expect(data.month, 6);
      expect(data.year, 2026);
    });

    test('kwh absent → 0 par défaut', () {
      final json = {
        'id': 'e2', 'user_id': 'user-1', 'appliance_id': 'app-1',
        'date': '2026-06-01T00:00:00.000',
        'week': 22, 'month': 6, 'year': 2026,
        'created_at': '2026-06-01T00:00:00.000',
      };
      final data = EnergyData.fromJson(json);
      expect(data.kwh, 0.0);
    });

    test('cumulative_kwh absent → null', () {
      final json = {
        'id': 'e3', 'user_id': 'user-1', 'appliance_id': 'app-1',
        'date': '2026-06-01T00:00:00.000', 'kwh': 1.0,
        'week': 22, 'month': 6, 'year': 2026,
        'created_at': '2026-06-01T00:00:00.000',
      };
      final data = EnergyData.fromJson(json);
      expect(data.cumulativeKwh, null);
    });

    test('kwh entier (int) converti en double', () {
      final json = {
        'id': 'e4', 'user_id': 'user-1', 'appliance_id': 'app-1',
        'date': '2026-06-01T00:00:00.000', 'kwh': 3,
        'week': 22, 'month': 6, 'year': 2026,
        'created_at': '2026-06-01T00:00:00.000',
      };
      final data = EnergyData.fromJson(json);
      expect(data.kwh, 3.0);
      expect(data.kwh, isA<double>());
    });
  });

  group('EnergyData — toJson', () {
    final kData = EnergyData(
      id: 'e1', userId: 'user-1', applianceId: 'app-1',
      date: DateTime(2026, 6, 1),
      kwh: 2.5, cumulativeKwh: 15.3,
      week: 22, month: 6, year: 2026,
      createdAt: DateTime(2026, 6, 1),
    );

    test('toJson produit les clés correctes', () {
      final json = kData.toJson();
      expect(json['id'], 'e1');
      expect(json['user_id'], 'user-1');
      expect(json['appliance_id'], 'app-1');
      expect(json['kwh'], 2.5);
      expect(json['cumulative_kwh'], 15.3);
      expect(json['week'], 22);
      expect(json['month'], 6);
      expect(json['year'], 2026);
    });

    test('toJson avec cumulativeKwh null', () {
      final dataNoKwh = EnergyData(
        id: 'e2', userId: 'user-1', applianceId: 'app-1',
        date: DateTime(2026, 6, 1), kwh: 0,
        week: 22, month: 6, year: 2026,
        createdAt: DateTime(2026, 6, 1),
      );
      final json = dataNoKwh.toJson();
      expect(json['cumulative_kwh'], null);
    });

    test('roundtrip fromJson → toJson préserve les données', () {
      final original = {
        'id': 'rt', 'user_id': 'user-rt', 'appliance_id': 'app-rt',
        'date': '2026-06-01T00:00:00.000',
        'kwh': 1.5, 'cumulative_kwh': 10.0,
        'week': 22, 'month': 6, 'year': 2026,
        'created_at': '2026-06-01T00:00:00.000',
      };
      final data = EnergyData.fromJson(original);
      final json = data.toJson();
      expect(json['kwh'], original['kwh']);
      expect(json['week'], original['week']);
      expect(json['year'], original['year']);
    });
  });
}