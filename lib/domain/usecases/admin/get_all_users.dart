import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:dartz/dartz.dart';

class GetAllUsers {
  final AdminRepository _repository;
  GetAllUsers(this._repository);

  Future<Either<Failure, List<User>>> call() {
    return _repository.getAllUsers();
  }
}
