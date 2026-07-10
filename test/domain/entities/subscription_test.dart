import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/domain/entities/subscription.dart';

void main() {
  final kCreatedAt = DateTime(2026, 1, 1);

  final kVipSubscription = Subscription(
    id: 'sub-1',
    userId: 'user-1',
    type: SubscriptionType.vip,
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2027, 1, 1),
    isActive: true,
    autoRenew: true,
    createdAt: kCreatedAt,
  );

  final kFreeSubscription = Subscription(
    id: 'sub-2',
    userId: 'user-2',
    type: SubscriptionType.free,
    startDate: DateTime(2026, 1, 1),
    endDate: null,
    isActive: true,
    autoRenew: false,
    createdAt: kCreatedAt,
  );

  group('Subscription — getters', () {
    test('isVip retourne true pour type vip', () {
      expect(kVipSubscription.isVip, true);
    });

    test('isVip retourne false pour type free', () {
      expect(kFreeSubscription.isVip, false);
    });

    test('isValid retourne true pour abonnement actif non expiré', () {
      expect(kVipSubscription.isValid, true);
    });

    test('isValid retourne false pour abonnement inactif', () {
      final inactive = Subscription(
        id: 'sub-3', userId: 'user-1', type: SubscriptionType.vip,
        startDate: DateTime(2026, 1, 1), endDate: DateTime(2027, 1, 1),
        isActive: false, autoRenew: false, createdAt: kCreatedAt,
      );
      expect(inactive.isValid, false);
    });

    test('isValid retourne false pour abonnement expiré', () {
      final expired = Subscription(
        id: 'sub-4', userId: 'user-1', type: SubscriptionType.vip,
        startDate: DateTime(2024, 1, 1), endDate: DateTime(2024, 12, 31),
        isActive: true, autoRenew: false, createdAt: kCreatedAt,
      );
      expect(expired.isValid, false);
    });

    test('isValid retourne true si endDate null (illimité)', () {
      expect(kFreeSubscription.isValid, true);
    });
  });

  group('Subscription — fromJson', () {
    test('parse un JSON VIP complet correctement', () {
      final json = {
        'id': 'sub-1', 'user_id': 'user-1', 'type': 'vip',
        'start_date': '2026-01-01T00:00:00.000',
        'end_date': '2027-01-01T00:00:00.000',
        'is_active': true, 'auto_renew': true,
        'created_at': '2026-01-01T00:00:00.000',
      };
      final sub = Subscription.fromJson(json);
      expect(sub.id, 'sub-1');
      expect(sub.type, SubscriptionType.vip);
      expect(sub.isActive, true);
      expect(sub.autoRenew, true);
      expect(sub.endDate, DateTime(2027, 1, 1));
    });

    test('parse type free correctement', () {
      final json = {
        'id': 'sub-2', 'user_id': 'user-2', 'type': 'free',
        'start_date': '2026-01-01T00:00:00.000',
        'is_active': true, 'auto_renew': false,
        'created_at': '2026-01-01T00:00:00.000',
      };
      final sub = Subscription.fromJson(json);
      expect(sub.type, SubscriptionType.free);
      expect(sub.endDate, null);
    });

    test('is_active absent → true par défaut', () {
      final json = {
        'id': 'sub-3', 'user_id': 'user-1', 'type': 'vip',
        'start_date': '2026-01-01T00:00:00.000',
        'created_at': '2026-01-01T00:00:00.000',
      };
      final sub = Subscription.fromJson(json);
      expect(sub.isActive, true);
    });

    test('auto_renew absent → false par défaut', () {
      final json = {
        'id': 'sub-4', 'user_id': 'user-1', 'type': 'free',
        'start_date': '2026-01-01T00:00:00.000',
        'created_at': '2026-01-01T00:00:00.000',
      };
      final sub = Subscription.fromJson(json);
      expect(sub.autoRenew, false);
    });
  });

  group('Subscription — toJson', () {
    test('toJson produit les clés correctes', () {
      final json = kVipSubscription.toJson();
      expect(json['id'], 'sub-1');
      expect(json['user_id'], 'user-1');
      expect(json['type'], 'vip');
      expect(json['is_active'], true);
      expect(json['auto_renew'], true);
    });

    test('toJson inclut end_date si défini', () {
      final json = kVipSubscription.toJson();
      expect(json['end_date'], isNotNull);
    });

    test('toJson produit end_date null si absent', () {
      final json = kFreeSubscription.toJson();
      expect(json['end_date'], null);
    });

    test('roundtrip fromJson → toJson préserve les données', () {
      final original = {
        'id': 'sub-rt', 'user_id': 'user-rt', 'type': 'vip',
        'start_date': '2026-01-01T00:00:00.000',
        'end_date': '2027-01-01T00:00:00.000',
        'is_active': true, 'auto_renew': true,
        'created_at': '2026-01-01T00:00:00.000',
      };
      final sub = Subscription.fromJson(original);
      final json = sub.toJson();
      expect(json['id'], original['id']);
      expect(json['type'], original['type']);
      expect(json['is_active'], original['is_active']);
    });
  });
}
