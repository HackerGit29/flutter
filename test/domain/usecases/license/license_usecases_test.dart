import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:aricie/domain/repositories/license_repository.dart';
import 'package:aricie/domain/usecases/license/check_license_validity.dart';
import 'package:aricie/domain/usecases/license/is_feature_allowed.dart';
import 'package:aricie/domain/usecases/license/get_user_subscription.dart';
import 'package:aricie/domain/usecases/license/cancel_subscription.dart';
import 'package:aricie/domain/usecases/license/upgrade_to_vip.dart';
import 'package:dartz/dartz.dart';

// ─── Mock ────────────────────────────────────────────────────────────────────

final kVipSub = Subscription(
  id: 'sub-1', userId: 'user-1', type: SubscriptionType.vip,
  startDate: DateTime(2026, 1, 1), endDate: DateTime(2027, 1, 1),
  isActive: true, autoRenew: true, createdAt: DateTime(2026, 1, 1),
);

final kFreeSub = Subscription(
  id: 'sub-2', userId: 'user-1', type: SubscriptionType.free,
  startDate: DateTime(2026, 1, 1), endDate: null,
  isActive: true, autoRenew: false, createdAt: DateTime(2026, 1, 1),
);

class MockLicenseRepo implements LicenseRepository {
  final bool licenseValid;
  final bool featureAllowed;
  final bool operationFails;
  final Subscription subscription;

  MockLicenseRepo({
    this.licenseValid = true,
    this.featureAllowed = true,
    this.operationFails = false,
    Subscription? subscription,
  }) : subscription = subscription ?? kVipSub;

  @override
  Future<Either<Failure, bool>> checkLicenseValidity() async {
    if (operationFails) return Left(const ServerFailure());
    return Right(licenseValid);
  }

  @override
  Future<Either<Failure, bool>> isFeatureAllowed(String featureName) async {
    if (operationFails) return Left(const ServerFailure());
    return Right(featureAllowed);
  }

  @override
  Future<Either<Failure, Subscription>> getUserSubscription() async {
    if (operationFails) return Left(const NoActiveSubscriptionFailure());
    return Right(subscription);
  }

  @override
  Future<Either<Failure, Subscription>> getUserSubscriptionForUser(
      String userId) async {
    if (operationFails) return Left(const NoActiveSubscriptionFailure());
    return Right(subscription);
  }

  @override
  Future<Either<Failure, Subscription>> redeemProductKey(String key) async =>
      Left(const ServerFailure('mock'));

  @override
  Future<Either<Failure, Subscription>> upgradeToVip(String licenseKey) async {
    if (operationFails) return Left(const ServerFailure());
    return Right(kVipSub);
  }

  @override
  Future<Either<Failure, Subscription>> cancelSubscription() async {
    if (operationFails) return Left(const ServerFailure());
    return Right(kFreeSub);
  }
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  // ─── CheckLicenseValidity ─────────────────────────────────────────────────
  group('CheckLicenseValidity', () {
    test('retourne true pour une licence valide', () async {
      final uc = CheckLicenseValidity(MockLicenseRepo(licenseValid: true));
      final result = await uc.call();
      expect(result.isRight(), true);
      result.fold((_) {}, (valid) => expect(valid, true));
    });

    test('retourne false pour une licence expirée', () async {
      final uc = CheckLicenseValidity(MockLicenseRepo(licenseValid: false));
      final result = await uc.call();
      expect(result.isRight(), true);
      result.fold((_) {}, (valid) => expect(valid, false));
    });

    test('retourne Failure si le repo échoue', () async {
      final uc = CheckLicenseValidity(MockLicenseRepo(operationFails: true));
      final result = await uc.call();
      expect(result.isLeft(), true);
    });
  });

  // ─── IsFeatureAllowed ─────────────────────────────────────────────────────
  group('IsFeatureAllowed', () {
    test('retourne true si la fonctionnalité est autorisée', () async {
      final uc = IsFeatureAllowed(MockLicenseRepo(featureAllowed: true));
      final result = await uc.call('ai_chat');
      expect(result.isRight(), true);
      result.fold((_) {}, (allowed) => expect(allowed, true));
    });

    test('retourne false si la fonctionnalité est refusée', () async {
      final uc = IsFeatureAllowed(MockLicenseRepo(featureAllowed: false));
      final result = await uc.call('ai_chat');
      expect(result.isRight(), true);
      result.fold((_) {}, (allowed) => expect(allowed, false));
    });

    test('fonctionne pour différentes fonctionnalités', () async {
      final uc = IsFeatureAllowed(MockLicenseRepo(featureAllowed: true));
      for (final feature in ['ai_chat', 'voice', 'export', 'multi_box']) {
        final result = await uc.call(feature);
        expect(result.isRight(), true);
      }
    });

    test('retourne Failure si le repo échoue', () async {
      final uc = IsFeatureAllowed(MockLicenseRepo(operationFails: true));
      final result = await uc.call('ai_chat');
      expect(result.isLeft(), true);
    });
  });

  // ─── GetUserSubscription ──────────────────────────────────────────────────
  group('GetUserSubscription', () {
    test('retourne l\'abonnement VIP de l\'utilisateur', () async {
      final uc = GetUserSubscription(MockLicenseRepo());
      final result = await uc.call();
      expect(result.isRight(), true);
      result.fold((_) {}, (sub) {
        expect(sub.type, SubscriptionType.vip);
        expect(sub.isActive, true);
      });
    });

    test('retourne l\'abonnement free', () async {
      final uc = GetUserSubscription(
          MockLicenseRepo(subscription: kFreeSub));
      final result = await uc.call();
      expect(result.isRight(), true);
      result.fold((_) {}, (sub) => expect(sub.type, SubscriptionType.free));
    });

    test('retourne NoActiveSubscriptionFailure si aucun abonnement', () async {
      final uc = GetUserSubscription(MockLicenseRepo(operationFails: true));
      final result = await uc.call();
      expect(result.isLeft(), true);
      result.fold(
          (f) => expect(f, isA<NoActiveSubscriptionFailure>()), (_) {});
    });

    test('callForUser retourne l\'abonnement d\'un utilisateur spécifique',
        () async {
      final uc = GetUserSubscription(MockLicenseRepo());
      final result = await uc.callForUser('user-1');
      expect(result.isRight(), true);
      result.fold((_) {}, (sub) => expect(sub.userId, 'user-1'));
    });

    test('callForUser retourne Failure si aucun abonnement', () async {
      final uc =
          GetUserSubscription(MockLicenseRepo(operationFails: true));
      final result = await uc.callForUser('user-1');
      expect(result.isLeft(), true);
    });
  });

  // ─── UpgradeToVip ─────────────────────────────────────────────────────────
  group('UpgradeToVip', () {
    test('upgrade vers VIP avec succès', () async {
      final uc = UpgradeToVip(MockLicenseRepo());
      final result = await uc.call('LICENSE-KEY-TEST');
      expect(result.isRight(), true);
      result.fold((_) {}, (sub) => expect(sub.type, SubscriptionType.vip));
    });

    test('retourne Failure si l\'upgrade échoue', () async {
      final uc = UpgradeToVip(MockLicenseRepo(operationFails: true));
      final result = await uc.call('LICENSE-KEY-TEST');
      expect(result.isLeft(), true);
    });
  });

  // ─── CancelSubscription ───────────────────────────────────────────────────
  group('CancelSubscription', () {
    test('annule l\'abonnement avec succès', () async {
      final uc = CancelSubscription(MockLicenseRepo());
      final result = await uc.call();
      expect(result.isRight(), true);
    });

    test('retourne Failure si l\'annulation échoue', () async {
      final uc = CancelSubscription(MockLicenseRepo(operationFails: true));
      final result = await uc.call();
      expect(result.isLeft(), true);
    });
  });
}
