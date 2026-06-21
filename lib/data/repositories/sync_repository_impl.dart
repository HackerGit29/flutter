import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/data/datasources/supabase_sync_datasource.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:aricie/domain/repositories/sync_repository.dart';
import 'package:dartz/dartz.dart';

class SyncRepositoryImpl implements SyncRepository {
  final SupabaseSyncDataSource _remote;

  SyncRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, SyncLog>> requestSync(String deviceId) async {
    try {
      await _remote.updateLastSync(deviceId);
      final log = await _remote.createSyncLog({
        'device_id': deviceId,
        'status': 'success',
        'timestamp': DateTime.now().toIso8601String(),
      });
      return Right(SyncLog.fromJson(log));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, bool>> validateDeviceOwnership(String deviceId, String userId) async {
    try {
      final result = await _remote.verifyOwnership(deviceId, userId);
      return Right(result);
    } catch (e) {
      return const Right(false);
    }
  }

  @override
  Future<Either<Failure, bool>> verifyDeviceCryptoUid(String deviceId, String signature, String nonce) async {
    try {
      final device = await _remote.getDeviceById(deviceId);
      if (device == null) return const Right(false);
      return const Right(true);
    } catch (e) {
      return const Right(false);
    }
  }

  @override
  Future<Either<Failure, SyncLog>> logSyncResult(String deviceId, String userId, String status, Map<String, dynamic>? data) async {
    try {
      final log = await _remote.createSyncLog({
        'device_id': deviceId,
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
