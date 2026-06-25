import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class ForceSync {
  final AdminRepository _adminRepo;
  final AuthRepository _authRepo;
  ForceSync(this._adminRepo, this._authRepo);

  Future<Either<Failure, SyncLog>> call(String boxId) async {
    final currentUser = await _authRepo.getCurrentUser();
    final user = currentUser.getOrElse(() => null);
    if (user == null || !user.isAdmin) return Left(AdminPermissionFailure());

    final result = await _adminRepo.forceSync(boxId);
    if (result.isRight()) {
      await _adminRepo.logAdminAction(
        adminId: user.id,
        action: 'force_sync',
        targetType: 'box',
        targetId: boxId,
      );
    }
    return result;
  }
}
