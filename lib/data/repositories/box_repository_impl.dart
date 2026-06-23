import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/data/datasources/supabase_box_datasource.dart';
import 'package:aricie/data/datasources/supabase_appliance_datasource.dart';
import 'package:aricie/data/datasources/local_datasource.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/repositories/box_repository.dart';
import 'package:dartz/dartz.dart';

class BoxRepositoryImpl implements BoxRepository {
  final SupabaseBoxDataSource _remote;
  final SupabaseApplianceDataSource _applianceRemote;
  final LocalDataSource _local;

  BoxRepositoryImpl(this._remote, this._applianceRemote, this._local);

  @override
  Future<Either<Failure, Box>> addBox(String name, String? location) async {
    try {
      final userId = await _local.getCachedUserId();
      if (userId == null) return Left(SessionExpiredFailure());
      final data = await _remote.addBox(name, location, userId);
      final box = Box.fromJson(data);
      await _applianceRemote.createAppliancesForBox(box.id, userId);
      return Right(box);
    } on SessionExpiredFailure {
      return Left(SessionExpiredFailure());
    } catch (e) {
      return Left(ServerFailure('Erreur lors de l\'ajout du boîtier'));
    }
  }

  @override
  Future<Either<Failure, void>> removeBox(String boxId) async {
    try {
      await _remote.removeBox(boxId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<Box>>> getUserBoxes() async {
    try {
      final userId = await _local.getCachedUserId();
      if (userId == null) return Left(SessionExpiredFailure());
      final data = await _remote.getUserBoxes(userId);
      return Right(data.map((json) => Box.fromJson(json)).toList());
    } on SessionExpiredFailure {
      return Left(SessionExpiredFailure());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Box>> pairBoxWithUid(String boxId, String uidHardware, String signature) async {
    try {
      final userId = await _local.getCachedUserId();
      if (userId == null) return Left(SessionExpiredFailure());

      final existing = await _remote.findBoxByUid(uidHardware);
      if (existing != null && existing['user_id'] != userId) {
        return Left(DeviceAlreadyAssignedFailure());
      }

      final data = await _remote.pairBox(boxId, uidHardware, userId);
      return Right(Box.fromJson(data));
    } on DeviceAlreadyAssignedFailure {
      return Left(DeviceAlreadyAssignedFailure());
    } catch (e) {
      return Left(DeviceNotIdentifiedFailure());
    }
  }

  @override
  Future<Either<Failure, Box>> identifyBox(String uidHardware) async {
    try {
      final data = await _remote.findBoxByUid(uidHardware);
      if (data == null) return Left(DeviceNotFoundFailure());
      return Right(Box.fromJson(data));
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
