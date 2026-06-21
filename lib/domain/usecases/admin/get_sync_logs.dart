import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class GetSyncLogs {
  final AdminRepository _adminRepo;
  final AuthRepository _authRepo;
  GetSyncLogs(this._adminRepo, this._authRepo);

  Future<Either<Failure, List<SyncLog>>> call({String? userId, String? deviceId}) async {
    final currentUser = await _authRepo.getCurrentUser();
    final user = currentUser.getOrElse(() => null);
    if (user == null || !user.isAdmin) return Left(AdminPermissionFailure());
    return _adminRepo.getSyncLogs(userId: userId, deviceId: deviceId);
  }
}
