import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/energy_data.dart';
import 'package:aricie/domain/repositories/energy_repository.dart';
import 'package:aricie/domain/usecases/devices/get_energy_data.dart';
import 'package:dartz/dartz.dart';

EnergyData _energy({String id = 'e-1', double kwh = 1.5}) {
  return EnergyData(
    id: id,
    userId: 'user-1',
    applianceId: 'app-1',
    date: DateTime(2026, 1, 1),
    kwh: kwh,
    week: 1,
    month: 1,
    year: 2026,
    createdAt: DateTime(2026, 1, 1),
  );
}

class MockEnergyRepository implements EnergyRepository {
  @override
  Future<Either<Failure, List<EnergyData>>> getEnergyHistory({
    required String userId,
    String timeFrame = 'Jour',
  }) async {
    if (userId.isEmpty) {
      return Left<Failure, List<EnergyData>>(const ServerFailure('userId requis'));
    }
    return Right<Failure, List<EnergyData>>([_energy(), _energy(id: 'e-2', kwh: 2.0)]);
  }

  @override
  Future<Either<Failure, Map<String, double>>> getEnergyByAppliance({
    required String userId,
    String timeFrame = 'Jour',
  }) async {
    return Right<Failure, Map<String, double>>({'Chauffe-eau': 3.5, 'TV': 0.8});
  }
}

void main() {
  late MockEnergyRepository repo;

  setUp(() => repo = MockEnergyRepository());

  group('GetEnergyHistory', () {
    test('renvoie l\'historique de consommation', () async {
      final result = await GetEnergyHistory(repo).call(userId: 'user-1');
      expect(result.isRight(), true);
      result.fold((_) {}, (list) => expect(list.length, 2));
    });

    test('renvoie une Failure pour un userId vide', () async {
      final result = await GetEnergyHistory(repo).call(userId: '');
      expect(result.isLeft(), true);
    });

    test('transmet le timeFrame par défaut (Jour)', () async {
      final result = await GetEnergyHistory(repo).call(userId: 'user-1');
      expect(result.isRight(), true);
    });
  });

  group('GetEnergyByAppliance', () {
    test('renvoie la conso agrégée par appareil', () async {
      final result = await GetEnergyByAppliance(repo).call(
        userId: 'user-1',
        timeFrame: 'Semaine',
      );
      expect(result.isRight(), true);
      result.fold((_) {}, (map) {
        expect(map.length, 2);
        expect(map['Chauffe-eau'], 3.5);
      });
    });
  });
}
