import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/appliance.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class CreateAppliancesForBox {
  final AdminRepository _adminRepo;
  final AuthRepository _authRepo;
  CreateAppliancesForBox(this._adminRepo, this._authRepo);

  Future<Either<Failure, List<Appliance>>> call(String boxId, String userId) async {
    final currentUser = await _authRepo.getCurrentUser();
    final user = currentUser.getOrElse(() => null);
    if (user == null || !user.isAdmin) return Left(AdminPermissionFailure());

    final result = await _adminRepo.createAppliancesForBox(boxId, userId);
    if (result.isRight()) {
      await _adminRepo.logAdminAction(
        adminId: user.id,
        action: 'create_appliances',
        targetType: 'box',
        targetId: boxId,
        details: {'appliance_count': (result.getOrElse(() => [])).length},
      );
    }
    return result;
  }
}
