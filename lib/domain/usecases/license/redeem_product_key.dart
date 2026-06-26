import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:aricie/domain/repositories/license_repository.dart';
import 'package:dartz/dartz.dart';

class RedeemProductKey {
  final LicenseRepository _repository;
  RedeemProductKey(this._repository);

  Future<Either<Failure, Subscription>> call(String key) {
    return _repository.redeemProductKey(key);
  }
}
