import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class GetCurrentUser {
  final AuthRepository _repository;
  GetCurrentUser(this._repository);

  Future<Either<Failure, User?>> call() {
    return _repository.getCurrentUser();
  }
}
