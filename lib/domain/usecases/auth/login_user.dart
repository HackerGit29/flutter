import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class LoginUser {
  final AuthRepository _repository;
  LoginUser(this._repository);

  Future<Either<Failure, User>> call(String email, String password) {
    return _repository.login(email, password);
  }
}
