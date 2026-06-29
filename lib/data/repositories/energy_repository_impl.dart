import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/data/datasources/supabase_energy_datasource.dart';
import 'package:aricie/domain/entities/energy_data.dart';
import 'package:aricie/domain/repositories/energy_repository.dart';
import 'package:dartz/dartz.dart';

class EnergyRepositoryImpl implements EnergyRepository {
  final SupabaseEnergyDataSource _dataSource;

  EnergyRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, List<EnergyData>>> getEnergyHistory({
    required String userId,
    String timeFrame = 'Jour',
  }) async {
    try {
      final data = await _dataSource.getEnergyHistory(
        userId: userId,
        timeFrame: timeFrame,
      );
      final entities = data.map((e) => EnergyData.fromJson(e)).toList();
      return Right(entities);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, double>>> getEnergyByAppliance({
    required String userId,
    String timeFrame = 'Jour',
  }) async {
    try {
      final data = await _dataSource.getEnergyByAppliance(
        userId: userId,
        timeFrame: timeFrame,
      );
      final result = <String, double>{};
      for (final row in data) {
        final applianceId = row['appliance_id'] as String;
        final value = (row['kwh'] as num?)?.toDouble() ?? 0.0;
        result[applianceId] = (result[applianceId] ?? 0.0) + value;
      }
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
