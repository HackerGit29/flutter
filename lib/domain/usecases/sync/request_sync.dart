import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:aricie/domain/repositories/sync_repository.dart';
import 'package:aricie/domain/repositories/device_repository.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class RequestSync {
  final SyncRepository _syncRepo;
  final DeviceRepository _deviceRepo;
  final AuthRepository _authRepo;
  RequestSync(this._syncRepo, this._deviceRepo, this._authRepo);

  Future<Either<Failure, SyncLog>> call(String deviceId) async {
    final currentUser = await _authRepo.getCurrentUser();
    final user = currentUser.getOrElse(() => null);
    if (user == null) return Left(SessionExpiredFailure());

    final ownership = await _syncRepo.validateDeviceOwnership(deviceId, user.id);
    final isOwner = ownership.getOrElse(() => false);
    if (!isOwner) {
      await _syncRepo.logSyncResult(deviceId, user.id, 'unauthorized', null);
      return Left(SyncUnauthorizedFailure());
    }

    final deviceResult = await _deviceRepo.getUserDevices();
    final devices = deviceResult.getOrElse(() => []);
    final device = devices.where((d) => d.id == deviceId).firstOrNull;
    if (device == null) return Left(DeviceNotFoundFailure());
    if (device.isBlocked) return Left(DeviceBlockedFailure());

    return _syncRepo.requestSync(deviceId);
  }
}
