import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class ResetPassword {
  final AuthRepository _repository;
  ResetPassword(this._repository);

  Future<Either<Failure, void>> call(String email) {
    return _repository.resetPassword(email);
  }
}
