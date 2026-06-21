import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:aricie/domain/repositories/sync_repository.dart';
import 'package:dartz/dartz.dart';

class LogSyncResult {
  final SyncRepository _repository;
  LogSyncResult(this._repository);

  Future<Either<Failure, SyncLog>> call(String deviceId, String userId, String status, Map<String, dynamic>? data) {
    return _repository.logSyncResult(deviceId, userId, status, data);
  }
}
