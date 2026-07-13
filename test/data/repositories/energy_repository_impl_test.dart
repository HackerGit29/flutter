
import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/energy_data.dart';
import 'package:aricie/data/datasources/supabase_energy_datasource.dart';
import 'package:aricie/data/repositories/energy_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseEnergyDataSource extends Mock implements SupabaseEnergyDataSource {}

void main() {
  late MockSupabaseEnergyDataSource mockDataSource;
  late EnergyRepositoryImpl repository;

  setUp(() {
    mockDataSource = MockSupabaseEnergyDataSource();
    repository = EnergyRepositoryImpl(mockDataSource);
  });

  group('EnergyRepositoryImpl', () {
    const userId = 'user-123';
    const timeFrame = 'Jour';

    group('getEnergyHistory', () {
      test('should return list of EnergyData on success', () async {
        final mockData = [
          {
            'id': 'ed-1',
            'user_id': userId,
            'appliance_id': 'app-1',
            'date': '2026-01-01T00:00:00.000Z',
            'kwh': 1.5,
            'cumulative_kwh': 10.5,
            'week': 1,
            'month': 1,
            'year': 2026,
            'created_at': '2026-01-01T00:00:00.000Z',
          }
        ];

        when(() => mockDataSource.getEnergyHistory(
              userId: userId,
              timeFrame: timeFrame,
            )).thenAnswer((_) async => mockData);

        final result = await repository.getEnergyHistory(userId: userId, timeFrame: timeFrame);

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (list) {
          expect(list.length, 1);
          expect(list.first.id, 'ed-1');
          expect(list.first.kwh, 1.5);
        });
      });

      test('should return ServerFailure when datasource throws exception', () async {
        when(() => mockDataSource.getEnergyHistory(
              userId: userId,
              timeFrame: timeFrame,
            )).thenThrow(Exception('database connection failed'));

        final result = await repository.getEnergyHistory(userId: userId, timeFrame: timeFrame);

        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, contains('database connection failed'));
        }, (_) => fail('should fail'));
      });
    });

    group('getEnergyByAppliance', () {
      test('should return aggregate map on success', () async {
        final mockData = [
          {'appliance_id': 'app-1', 'kwh': 1.5},
          {'appliance_id': 'app-1', 'kwh': 2.0},
          {'appliance_id': 'app-2', 'kwh': 3.1},
        ];

        when(() => mockDataSource.getEnergyByAppliance(
              userId: userId,
              timeFrame: timeFrame,
            )).thenAnswer((_) async => mockData);

        final result = await repository.getEnergyByAppliance(userId: userId, timeFrame: timeFrame);

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (map) {
          expect(map.length, 2);
          expect(map['app-1'], 3.5);
          expect(map['app-2'], 3.1);
        });
      });

      test('should return ServerFailure when datasource throws exception', () async {
        when(() => mockDataSource.getEnergyByAppliance(
              userId: userId,
              timeFrame: timeFrame,
            )).thenThrow(Exception('network error'));

        final result = await repository.getEnergyByAppliance(userId: userId, timeFrame: timeFrame);

        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, contains('network error'));
        }, (_) => fail('should fail'));
      });
    });
  });
}
