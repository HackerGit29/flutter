import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/data/datasources/supabase_license_datasource.dart';
import 'package:aricie/data/datasources/local_datasource.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:aricie/domain/repositories/license_repository.dart';
import 'package:dartz/dartz.dart';

class LicenseRepositoryImpl implements LicenseRepository {
  final SupabaseLicenseDataSource _remote;
  final LocalDataSource _local;

  LicenseRepositoryImpl(this._remote, this._local);

  @override
  Future<Either<Failure, Subscription>> getUserSubscription() async {
    try {
      final userId = await _local.getCachedUserId();
      if (userId == null) return Left(SessionExpiredFailure());
      final data = await _remote.getUserSubscription(userId);
      if (data == null) return Left(NoActiveSubscriptionFailure());
      return Right(Subscription.fromJson(data));
    } on SessionExpiredFailure {
      return Left(SessionExpiredFailure());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Subscription>> upgradeToVip(String licenseKey) async {
    try {
      final userId = await _local.getCachedUserId();
      if (userId == null) return Left(SessionExpiredFailure());

      final existingSub = await _remote.getUserSubscription(userId);
      if (existingSub != null && existingSub['is_active'] == true) {
        return Left(AlreadyHasActiveSubscriptionFailure());
      }

      final licenseData = await _remote.getLicenseByKey(licenseKey);
      if (licenseData == null) return Left(LicenseExpiredFailure('Clé de licence invalide'));

      final sub = await _remote.createSubscription(userId, 'vip');
      await _remote.createLicense({
        'subscription_id': sub['id'],
        'license_key': licenseKey,
        'activation_date': DateTime.now().toIso8601String(),
      });

      return Right(Subscription.fromJson(sub));
    } on AlreadyHasActiveSubscriptionFailure {
      return Left(AlreadyHasActiveSubscriptionFailure());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Subscription>> cancelSubscription() async {
    try {
      final userId = await _local.getCachedUserId();
      if (userId == null) return Left(SessionExpiredFailure());

      final data = await _remote.getUserSubscription(userId);
      if (data == null) return Left(NoActiveSubscriptionFailure());

      final updated = await _remote.updateSubscription(data['id'] as String, {
        'is_active': false, 'end_date': DateTime.now().toIso8601String(),
      });
      return Right(Subscription.fromJson(updated));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, bool>> checkLicenseValidity() async {
    try {
      final userId = await _local.getCachedUserId();
      if (userId == null) return Left(SessionExpiredFailure());

      final subData = await _remote.getUserSubscription(userId);
      if (subData == null) return const Right(false);

      final sub = Subscription.fromJson(subData);
      return Right(sub.isValid);
    } catch (e) {
      return const Right(false);
    }
  }

  @override
  Future<Either<Failure, bool>> isFeatureAllowed(String featureName) async {
    final validity = await checkLicenseValidity();
    return validity.fold(
      (failure) => const Right(false),
      (valid) => Right(valid),
    );
  }

  @override
  Future<Either<Failure, Subscription>> redeemProductKey(String key) async {
    try {
      final userId = await _local.getCachedUserId();
      if (userId == null) return Left(SessionExpiredFailure());

      final existingSub = await _remote.getUserSubscription(userId);
      if (existingSub != null && existingSub['is_active'] == true) {
        return Left(AlreadyHasActiveSubscriptionFailure());
      }

      final keyData = await _remote.findProductKey(key);
      if (keyData == null) return Left(LicenseExpiredFailure('Clé produit invalide'));
      if (keyData['is_used'] == true) return Left(LicenseExpiredFailure('Clé produit déjà utilisée'));

      final claimed = await _remote.claimProductKey(keyData['id'] as String, userId);
      if (claimed == null) return Left(LicenseExpiredFailure('Clé déjà utilisée (concurrence)'));

      final sub = await _remote.createSubscription(userId, 'vip');
      return Right(Subscription.fromJson(sub));
    } on AlreadyHasActiveSubscriptionFailure {
      return Left(AlreadyHasActiveSubscriptionFailure());
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
