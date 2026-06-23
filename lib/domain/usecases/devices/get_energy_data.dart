import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/energy_data.dart';
import 'package:aricie/domain/repositories/energy_repository.dart';
import 'package:dartz/dartz.dart';

class GetEnergyHistory {
  final EnergyRepository repository;

  GetEnergyHistory(this.repository);

  Future<Either<Failure, List<EnergyData>>> call({
    required String userId,
    String timeFrame = 'Jour',
    int limit = 30,
  }) {
    return repository.getEnergyHistory(
      userId: userId,
      timeFrame: timeFrame,
      limit: limit,
    );
  }
}

class GetEnergyByAppliance {
  final EnergyRepository repository;

  GetEnergyByAppliance(this.repository);

  Future<Either<Failure, Map<String, double>>> call({
    required String userId,
    String timeFrame = 'Jour',
  }) {
    return repository.getEnergyByAppliance(
      userId: userId,
      timeFrame: timeFrame,
    );
  }
}
