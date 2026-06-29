import 'package:aricie/core/errors/failures.dart';
import 'package:dartz/dartz.dart';
import 'package:aricie/domain/entities/energy_data.dart';

abstract class EnergyRepository {
  Future<Either<Failure, List<EnergyData>>> getEnergyHistory({
    required String userId,
    String timeFrame = 'Jour',
  });

  Future<Either<Failure, Map<String, double>>> getEnergyByAppliance({
    required String userId,
    String timeFrame = 'Jour',
  });
}
