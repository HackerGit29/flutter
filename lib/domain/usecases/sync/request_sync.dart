import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:aricie/domain/repositories/sync_repository.dart';
import 'package:aricie/domain/repositories/box_repository.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class RequestSync {
  final SyncRepository _syncRepo;
  final BoxRepository _boxRepo;
  final AuthRepository _authRepo;
  RequestSync(this._syncRepo, this._boxRepo, this._authRepo);

  Future<Either<Failure, SyncLog>> call(String boxId) async {
    final currentUser = await _authRepo.getCurrentUser();
    final user = currentUser.getOrElse(() => null);
    if (user == null) return Left(SessionExpiredFailure());

    final ownership = await _syncRepo.validateBoxOwnership(boxId, user.id);
    final isOwner = ownership.getOrElse(() => false);
    if (!isOwner) {
      await _syncRepo.logSyncResult(boxId, user.id, 'unauthorized', null);
      return Left(SyncUnauthorizedFailure());
    }

    final boxResult = await _boxRepo.getUserBoxes();
    final boxes = boxResult.getOrElse(() => []);
    final box = boxes.where((b) => b.id == boxId).firstOrNull;
    if (box == null) return Left(DeviceNotFoundFailure());
    if (box.isBlocked) return Left(DeviceBlockedFailure());

    return _syncRepo.requestSync(boxId);
  }
}
