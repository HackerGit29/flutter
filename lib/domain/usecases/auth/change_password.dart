import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class ChangePassword {
  final AuthRepository _repository;
  ChangePassword(this._repository);

  Future<Either<Failure, void>> call(
    String currentPassword,
    String newPassword,
  ) {
    return _repository.changePassword(currentPassword, newPassword);
  }
}
