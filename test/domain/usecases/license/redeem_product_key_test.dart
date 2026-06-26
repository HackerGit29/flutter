import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:aricie/domain/repositories/license_repository.dart';
import 'package:aricie/domain/usecases/license/redeem_product_key.dart';
import 'package:dartz/dartz.dart';

class MockLicenseRepository implements LicenseRepository {
  @override
  Future<Either<Failure, Subscription>> redeemProductKey(String key) async {
    if (key == 'VALID-KEY') {
      return Right<Failure, Subscription>(Subscription(
        id: 'sub-1', userId: 'user-1', type: SubscriptionType.vip,
        startDate: DateTime.now(), endDate: DateTime.now().add(const Duration(days: 365)),
        isActive: true, autoRenew: false, createdAt: DateTime.now(),
      ));
    }
    if (key == 'ALREADY-USED') {
      return Left<Failure, Subscription>(ServerFailure('Cette clé a déjà été utilisée.'));
    }
    return Left<Failure, Subscription>(ServerFailure('Clé produit invalide.'));
  }

  @override
  Future<Either<Failure, Subscription>> getUserSubscription() async {
    return Right<Failure, Subscription>(Subscription(
      id: 'sub-0', userId: 'user-1', type: SubscriptionType.free,
      startDate: DateTime.now(), isActive: true, autoRenew: false, createdAt: DateTime.now(),
    ));
  }

  @override
  Future<Either<Failure, Subscription>> upgradeToVip(String licenseKey) async {
    return Left<Failure, Subscription>(const ServerFailure('Not implemented'));
  }

  @override
  Future<Either<Failure, Subscription>> cancelSubscription() async {
    return Left<Failure, Subscription>(const ServerFailure('Not implemented'));
  }

  @override
  Future<Either<Failure, bool>> checkLicenseValidity() async {
    return const Right<Failure, bool>(false);
  }

  @override
  Future<Either<Failure, bool>> isFeatureAllowed(String featureName) async {
    return const Right<Failure, bool>(false);
  }
}

void main() {
  late RedeemProductKey useCase;

  setUp(() {
    useCase = RedeemProductKey(MockLicenseRepository());
  });

  test('returns Subscription for a valid product key', () async {
    final result = await useCase('VALID-KEY');
    expect(result.isRight(), true);
    result.fold((_) {}, (sub) {
      expect(sub.type, SubscriptionType.vip);
      expect(sub.isActive, true);
    });
  });

  test('returns Failure for an already-used product key', () async {
    final result = await useCase('ALREADY-USED');
    expect(result.isLeft(), true);
    result.fold((f) {
      expect(f.message, contains('déjà été utilisée'));
    }, (_) {});
  });

  test('returns Failure for an invalid product key', () async {
    final result = await useCase('INVALID-KEY');
    expect(result.isLeft(), true);
    result.fold((f) {
      expect(f.message, contains('invalide'));
    }, (_) {});
  });
}
