import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class OverrideOwnership {
  final AdminRepository _adminRepo;
  final AuthRepository _authRepo;
  OverrideOwnership(this._adminRepo, this._authRepo);

  Future<Either<Failure, Box>> call(String boxId, String newUserId, String reason) async {
    final currentUser = await _authRepo.getCurrentUser();
    final user = currentUser.getOrElse(() => null);
    if (user == null || !user.isAdmin) return Left(AdminPermissionFailure());
    if (reason.trim().isEmpty) {
      return Left(AdminPermissionFailure('Une justification est requise'));
    }

    final result = await _adminRepo.overrideOwnership(boxId, newUserId);
    if (result.isRight()) {
      await _adminRepo.logAdminAction(
        adminId: user.id,
        action: 'override_ownership',
        targetType: 'box',
        targetId: boxId,
        details: {
          'new_user_id': newUserId,
          'reason': reason.trim(),
        },
      );
    }
    return result;
  }
}
