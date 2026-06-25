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

    final targetResult = await _adminRepo.getUser(targetUserId);
    Failure? targetFailure;
    User? target;
    targetResult.fold((failure) => targetFailure = failure, (loadedUser) => target = loadedUser);
    if (targetFailure != null) return Left(targetFailure!);
    if (target == null) return Left(ServerFailure());
    if (target.isAdmin) return Left(CannotModifyAdminFailure());

    final result = await _adminRepo.assignRole(targetUserId, role);
    if (result.isRight()) {
      await _adminRepo.logAdminAction(
        adminId: user.id,
        action: 'assign_role',
        targetType: 'user',
        targetId: targetUserId,
        details: {'role': role},
      );
    }
    return result;
  }
}
