import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:aricie/domain/repositories/license_repository.dart';
import 'package:dartz/dartz.dart';

class GetUserSubscription {
  final LicenseRepository _repository;
  GetUserSubscription(this._repository);

  Future<Either<Failure, Subscription>> call() {
    return _repository.getUserSubscription();
  }
}
