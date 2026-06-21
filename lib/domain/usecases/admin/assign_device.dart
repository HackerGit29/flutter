import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/device.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class AssignDevice {
  final AdminRepository _adminRepo;
  final AuthRepository _authRepo;
  AssignDevice(this._adminRepo, this._authRepo);

  Future<Either<Failure, Device>> call(String deviceId, String newUserId) async {
    final currentUser = await _authRepo.getCurrentUser();
    final user = currentUser.getOrElse(() => null);
    if (user == null || !user.isAdmin) return Left(AdminPermissionFailure());
    return _adminRepo.assignDevice(deviceId, newUserId);
  }
}
