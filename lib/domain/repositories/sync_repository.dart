import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:dartz/dartz.dart';

abstract class SyncRepository {
  Future<Either<Failure, SyncLog>> requestSync(String deviceId);
  Future<Either<Failure, bool>> validateDeviceOwnership(String deviceId, String userId);
  Future<Either<Failure, bool>> verifyDeviceCryptoUid(String deviceId, String signature, String nonce);
  Future<Either<Failure, SyncLog>> logSyncResult(String deviceId, String userId, String status, Map<String, dynamic>? data);
}
