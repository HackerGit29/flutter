import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class ResetDevice {
  final AdminRepository _adminRepo;
  final AuthRepository _authRepo;
  ResetDevice(this._adminRepo, this._authRepo);

  Future<Either<Failure, Box>> call(String boxId) async {
    final currentUser = await _authRepo.getCurrentUser();
    final user = currentUser.getOrElse(() => null);
    if (user == null || !user.isAdmin) return Left(AdminPermissionFailure());

    final result = await _adminRepo.resetBox(boxId);
    if (result.isRight()) {
      await _adminRepo.logAdminAction(
        adminId: user.id,
        action: 'reset_box',
        targetType: 'box',
        targetId: boxId,
      );
    }
    return result;
  }
}
