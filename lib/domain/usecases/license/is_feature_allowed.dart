import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/repositories/license_repository.dart';
import 'package:dartz/dartz.dart';

class IsFeatureAllowed {
  final LicenseRepository _repository;
  IsFeatureAllowed(this._repository);

  Future<Either<Failure, bool>> call(String featureName) {
    return _repository.isFeatureAllowed(featureName);
  }
}
