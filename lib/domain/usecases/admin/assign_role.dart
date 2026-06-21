import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class AssignRole {
  final AdminRepository _adminRepo;
  final AuthRepository _authRepo;
  AssignRole(this._adminRepo, this._authRepo);

  Future<Either<Failure, User>> call(String targetUserId, String role) async {
    final currentUser = await _authRepo.getCurrentUser();
    final user = currentUser.getOrElse(() => null);
    if (user == null || !user.isAdmin) return Left(AdminPermissionFailure());
    if (user.id == targetUserId) return Left(CannotModifySelfFailure());
    return _adminRepo.assignRole(targetUserId, role);
  }
}
