import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class AssignDevice {
  final AdminRepository _adminRepo;
  final AuthRepository _authRepo;
  AssignDevice(this._adminRepo, this._authRepo);

  Future<Either<Failure, Box>> call(String boxId, String newUserId) async {
    final currentUser = await _authRepo.getCurrentUser();
    final user = currentUser.getOrElse(() => null);
    if (user == null || !user.isAdmin) return Left(AdminPermissionFailure());

    final result = await _adminRepo.assignBox(boxId, newUserId);
    if (result.isRight()) {
      await _adminRepo.logAdminAction(
        adminId: user.id,
        action: 'assign_box',
        targetType: 'box',
        targetId: boxId,
        details: {'new_user_id': newUserId},
      );
    }
    return result;
  }
}
