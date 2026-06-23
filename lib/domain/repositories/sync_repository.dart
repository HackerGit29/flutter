import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:dartz/dartz.dart';

abstract class SyncRepository {
  Future<Either<Failure, SyncLog>> requestSync(String boxId);
  Future<Either<Failure, bool>> validateBoxOwnership(String boxId, String userId);
  Future<Either<Failure, bool>> verifyBoxCryptoUid(String boxId, String signature, String nonce);
  Future<Either<Failure, SyncLog>> logSyncResult(String boxId, String userId, String status, Map<String, dynamic>? data);
}
