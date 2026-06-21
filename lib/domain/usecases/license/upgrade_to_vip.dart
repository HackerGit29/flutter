import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:aricie/domain/repositories/license_repository.dart';
import 'package:dartz/dartz.dart';

class UpgradeToVip {
  final LicenseRepository _repository;
  UpgradeToVip(this._repository);

  Future<Either<Failure, Subscription>> call(String licenseKey) {
    return _repository.upgradeToVip(licenseKey);
  }
}
