import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/appliance.dart';
import 'package:aricie/data/datasources/supabase_appliance_datasource.dart';
import 'package:aricie/data/datasources/local_datasource.dart';
import 'package:aricie/data/repositories/appliance_repository_impl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';

class MockSupabaseApplianceDataSource extends Mock implements SupabaseApplianceDataSource {}
class MockLocalDataSource extends Mock implements LocalDataSource {}

void main() {
  late MockSupabaseApplianceDataSource mockRemote;
  late MockLocalDataSource mockLocal;
  late ApplianceRepositoryImpl repository;

  setUp(() {
    mockRemote = MockSupabaseApplianceDataSource();
    mockLocal = MockLocalDataSource();
    repository = ApplianceRepositoryImpl(mockRemote, mockLocal);
  });

  group('ApplianceRepositoryImpl', () {
    const userId = 'user-123';
    const boxId = 'box-123';
    const applianceId = 'app-123';
    final timestamp = DateTime(2026, 1, 1).toIso8601String();

    final testApplianceJson = {
      'id': applianceId,
      'box_id': boxId,
      'user_id': userId,
      'relay_index': 1,
      'name': 'Heater',
      'is_on': true,
      'created_at': timestamp,
    };

    group('getUserAppliances', () {
      test('should return list of appliances on success', () async {
        when(() => mockLocal.getCachedUserId()).thenAnswer((_) async => userId);
        when(() => mockRemote.getUserAppliances(userId)).thenAnswer((_) async => [testApplianceJson]);

        final result = await repository.getUserAppliances();

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (list) {
          expect(list.length, 1);
          expect(list.first.id, applianceId);
          expect(list.first.isOn, true);
        });
      });

      test('should return SessionExpiredFailure when no cached user id', () async {
        when(() => mockLocal.getCachedUserId()).thenAnswer((_) async => null);

        final result = await repository.getUserAppliances();

        expect(result.isLeft(), true);
        result.fold((failure) => expect(failure, isA<SessionExpiredFailure>()), (_) => fail('should fail'));
      });

      test('should return ServerFailure on remote exception', () async {
        when(() => mockLocal.getCachedUserId()).thenAnswer((_) async => userId);
        when(() => mockRemote.getUserAppliances(userId)).thenThrow(Exception('error'));

        final result = await repository.getUserAppliances();

        expect(result.isLeft(), true);
        result.fold((failure) => expect(failure, isA<ServerFailure>()), (_) => fail('should fail'));
      });
    });

    group('getBoxAppliances', () {
      test('should return list of appliances on success', () async {
        when(() => mockRemote.getBoxAppliances(boxId)).thenAnswer((_) async => [testApplianceJson]);

        final result = await repository.getBoxAppliances(boxId);

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (list) {
          expect(list.length, 1);
          expect(list.first.boxId, boxId);
        });
      });

      test('should return ServerFailure on exception', () async {
        when(() => mockRemote.getBoxAppliances(boxId)).thenThrow(Exception('error'));

        final result = await repository.getBoxAppliances(boxId);

        expect(result.isLeft(), true);
        result.fold((failure) => expect(failure, isA<ServerFailure>()), (_) => fail('should fail'));
      });
    });

    group('renameAppliance', () {
      test('should return renamed appliance on success', () async {
        when(() => mockRemote.updateApplianceName(applianceId, 'New Name')).thenAnswer((_) async => {
          ...testApplianceJson,
          'name': 'New Name',
        });

        final result = await repository.renameAppliance(applianceId, 'New Name');

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (app) {
          expect(app.id, applianceId);
          expect(app.name, 'New Name');
        });
      });

      test('should return ServerFailure on exception', () async {
        when(() => mockRemote.updateApplianceName(applianceId, 'New Name')).thenThrow(Exception('error'));

        final result = await repository.renameAppliance(applianceId, 'New Name');

        expect(result.isLeft(), true);
        result.fold((failure) => expect(failure, isA<ServerFailure>()), (_) => fail('should fail'));
      });
    });

    group('toggleAppliance', () {
      test('should return toggled appliance on success', () async {
        when(() => mockRemote.toggleAppliance(applianceId, false)).thenAnswer((_) async => {
          ...testApplianceJson,
          'is_on': false,
        });

        final result = await repository.toggleAppliance(applianceId, false);

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (app) {
          expect(app.id, applianceId);
          expect(app.isOn, false);
        });
      });

      test('should return ServerFailure on exception', () async {
        when(() => mockRemote.toggleAppliance(applianceId, false)).thenThrow(Exception('error'));

        final result = await repository.toggleAppliance(applianceId, false);

        expect(result.isLeft(), true);
        result.fold((failure) => expect(failure, isA<ServerFailure>()), (_) => fail('should fail'));
      });
    });
  });
}
