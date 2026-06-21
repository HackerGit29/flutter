import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/device.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class GetAllDevices {
  final AdminRepository _adminRepo;
  final AuthRepository _authRepo;
  GetAllDevices(this._adminRepo, this._authRepo);

  Future<Either<Failure, List<Device>>> call() async {
    final currentUser = await _authRepo.getCurrentUser();
    final user = currentUser.getOrElse(() => null);
    if (user == null || !user.isAdmin) return Left(AdminPermissionFailure());
    return _adminRepo.getAllDevices();
  }
}
