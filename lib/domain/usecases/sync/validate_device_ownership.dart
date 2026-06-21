import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/repositories/sync_repository.dart';
import 'package:dartz/dartz.dart';

class ValidateDeviceOwnership {
  final SyncRepository _repository;
  ValidateDeviceOwnership(this._repository);

  Future<Either<Failure, bool>> call(String deviceId, String userId) {
    return _repository.validateDeviceOwnership(deviceId, userId);
  }
}
