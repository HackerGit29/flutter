import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:aricie/domain/repositories/license_repository.dart';
import 'package:dartz/dartz.dart';

class CancelSubscription {
  final LicenseRepository _repository;
  CancelSubscription(this._repository);

  Future<Either<Failure, Subscription>> call() {
    return _repository.cancelSubscription();
  }
}
