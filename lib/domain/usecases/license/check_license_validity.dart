import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/repositories/license_repository.dart';
import 'package:dartz/dartz.dart';

class CheckLicenseValidity {
  final LicenseRepository _repository;
  CheckLicenseValidity(this._repository);

  Future<Either<Failure, bool>> call() {
    return _repository.checkLicenseValidity();
  }
}
