import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class ConfirmPasswordReset {
  final AuthRepository _repository;
  ConfirmPasswordReset(this._repository);

  Future<Either<Failure, void>> call(
    String email,
    String token,
    String newPassword,
  ) {
    return _repository.confirmPasswordReset(email, token, newPassword);
  }
}
