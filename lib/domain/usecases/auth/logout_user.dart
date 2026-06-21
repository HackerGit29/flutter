import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class LogoutUser {
  final AuthRepository _repository;
  LogoutUser(this._repository);

  Future<Either<Failure, void>> call() {
    return _repository.logout();
  }
}
