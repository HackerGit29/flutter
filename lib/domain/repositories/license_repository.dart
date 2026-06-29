import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:dartz/dartz.dart';

abstract class LicenseRepository {
  Future<Either<Failure, Subscription>> getUserSubscription();
  Future<Either<Failure, Subscription>> getUserSubscriptionForUser(String userId);
  Future<Either<Failure, Subscription>> upgradeToVip(String licenseKey);
  Future<Either<Failure, Subscription>> cancelSubscription();
  Future<Either<Failure, bool>> checkLicenseValidity();
  Future<Either<Failure, bool>> isFeatureAllowed(String featureName);
  Future<Either<Failure, Subscription>> redeemProductKey(String key);
}
