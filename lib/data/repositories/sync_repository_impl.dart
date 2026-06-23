import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/data/datasources/supabase_sync_datasource.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:aricie/domain/repositories/sync_repository.dart';
import 'package:dartz/dartz.dart';

class SyncRepositoryImpl implements SyncRepository {
  final SupabaseSyncDataSource _remote;

  SyncRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, SyncLog>> requestSync(String boxId) async {
    try {
      await _remote.updateLastSync(boxId);
      final log = await _remote.createSyncLog({
        'box_id': boxId,
        'status': 'success',
        'timestamp': DateTime.now().toIso8601String(),
      });
      return Right(SyncLog.fromJson(log));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, bool>> validateBoxOwnership(String boxId, String userId) async {
    try {
      final result = await _remote.verifyOwnership(boxId, userId);
      return Right(result);
    } catch (e) {
      return const Right(false);
    }
  }

  @override
  Future<Either<Failure, bool>> verifyBoxCryptoUid(String boxId, String signature, String nonce) async {
    try {
      final box = await _remote.getBoxById(boxId);
      if (box == null) return const Right(false);
      return const Right(true);
    } catch (e) {
      return const Right(false);
    }
  }

  @override
  Future<Either<Failure, SyncLog>> logSyncResult(String boxId, String userId, String status, Map<String, dynamic>? data) async {
    try {
      final log = await _remote.createSyncLog({
        'box_id': boxId,
        'user_id': userId,
        'status': status,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
      return Right(SyncLog.fromJson(log));
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
