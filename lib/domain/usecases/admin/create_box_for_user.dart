import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class CreateBoxForUser {
  final AdminRepository _adminRepo;
  final AuthRepository _authRepo;
  CreateBoxForUser(this._adminRepo, this._authRepo);

  Future<Either<Failure, Box>> call({
    required String uidHardware,
    required String name,
    String? location,
    required String userId,
  }) async {
    final currentUser = await _authRepo.getCurrentUser();
    final user = currentUser.getOrElse(() => null);
    if (user == null || !user.isAdmin) return Left(AdminPermissionFailure());

    final result = await _adminRepo.createBox(
      uidHardware: uidHardware,
      name: name,
      location: location,
      userId: userId,
    );
    if (result.isRight()) {
      await _adminRepo.logAdminAction(
        adminId: user.id,
        action: 'create_box',
        targetType: 'box',
        targetId: result.getOrElse(() => throw Exception()).id,
        details: {'uid_hardware': uidHardware, 'name': name, 'owner_user_id': userId},
      );
    }
    return result;
  }
}
