import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/data/datasources/supabase_appliance_datasource.dart';
import 'package:aricie/data/datasources/local_datasource.dart';
import 'package:aricie/domain/entities/appliance.dart';
import 'package:aricie/domain/repositories/appliance_repository.dart';
import 'package:dartz/dartz.dart';

class ApplianceRepositoryImpl implements ApplianceRepository {
  final SupabaseApplianceDataSource _remote;
  final LocalDataSource _local;

  ApplianceRepositoryImpl(this._remote, this._local);

  @override
  Future<Either<Failure, List<Appliance>>> getUserAppliances() async {
    try {
      final userId = await _local.getCachedUserId();
      if (userId == null) return Left(SessionExpiredFailure());
      final data = await _remote.getUserAppliances(userId);
      return Right(data.map((json) => Appliance.fromJson(json)).toList());
    } on SessionExpiredFailure {
      return Left(SessionExpiredFailure());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<Appliance>>> getBoxAppliances(String boxId) async {
    try {
      final data = await _remote.getBoxAppliances(boxId);
      return Right(data.map((json) => Appliance.fromJson(json)).toList());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Appliance>> renameAppliance(String applianceId, String name) async {
    try {
      final data = await _remote.updateApplianceName(applianceId, name);
      return Right(Appliance.fromJson(data));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Appliance>> toggleAppliance(String applianceId, bool on) async {
    try {
      final data = await _remote.toggleAppliance(applianceId, on);
      return Right(Appliance.fromJson(data));
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
