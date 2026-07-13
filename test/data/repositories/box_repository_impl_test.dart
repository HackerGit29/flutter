import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/data/datasources/local_datasource.dart';
import 'package:aricie/data/datasources/supabase_appliance_datasource.dart';
import 'package:aricie/data/datasources/supabase_box_datasource.dart';
import 'package:aricie/data/repositories/box_repository_impl.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:dartz/dartz.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseBoxDataSource extends Mock implements SupabaseBoxDataSource {}
class MockSupabaseApplianceDataSource extends Mock implements SupabaseApplianceDataSource {}
class MockLocalDataSource extends Mock implements LocalDataSource {}

void main() {
  late MockSupabaseBoxDataSource mockRemote;
  late MockSupabaseApplianceDataSource mockApplianceRemote;
  late MockLocalDataSource mockLocal;
  late BoxRepositoryImpl repository;

  setUp(() {
    mockRemote = MockSupabaseBoxDataSource();
    mockApplianceRemote = MockSupabaseApplianceDataSource();
    mockLocal = MockLocalDataSource();
    repository = BoxRepositoryImpl(mockRemote, mockApplianceRemote, mockLocal);
  });

  group('BoxRepositoryImpl', () {
    const userId = 'user-123';
    const boxId = 'box-123';
    const name = 'Salon';
    const location = 'Paris';
    const uidHardware = 'hardware-uid-12345';
    const signature = 'sig-123';

    final mockBoxJson = {
      'id': boxId,
      'name': name,
      'location': location,
      'user_id': userId,
      'uid_hardware': uidHardware,
      'created_at': '2026-01-01T00:00:00.000Z',
    };

    group('addBox', () {
      test('should return Box and call remote service on success', () async {
        when(() => mockLocal.getCachedUserId()).thenAnswer((_) async => userId);
        when(() => mockRemote.addBox(name, location, userId)).thenAnswer((_) async => mockBoxJson);
        when(() => mockApplianceRemote.createAppliancesForBox(boxId, userId)).thenAnswer((_) async => <Map<String, dynamic>>[]);

        final result = await repository.addBox(name, location);

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (box) {
          expect(box.id, boxId);
          expect(box.name, name);
        });
        verify(() => mockLocal.getCachedUserId()).called(1);
        verify(() => mockRemote.addBox(name, location, userId)).called(1);
        verify(() => mockApplianceRemote.createAppliancesForBox(boxId, userId)).called(1);
      });

      test('should return SessionExpiredFailure when no cached user ID', () async {
        when(() => mockLocal.getCachedUserId()).thenAnswer((_) async => null);

        final result = await repository.addBox(name, location);

        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<SessionExpiredFailure>());
        }, (_) => fail('should fail'));
        verify(() => mockLocal.getCachedUserId()).called(1);
        verifyNever(() => mockRemote.addBox(any(), any(), any()));
      });

      test('should return ServerFailure when remote fails', () async {
        when(() => mockLocal.getCachedUserId()).thenAnswer((_) async => userId);
        when(() => mockRemote.addBox(name, location, userId)).thenThrow(Exception('database error'));

        final result = await repository.addBox(name, location);

        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<ServerFailure>());
        }, (_) => fail('should fail'));
      });
    });

    group('removeBox', () {
      test('should return Right(null) on success', () async {
        when(() => mockRemote.removeBox(boxId)).thenAnswer((_) async => {});

        final result = await repository.removeBox(boxId);

        expect(result.isRight(), true);
        verify(() => mockRemote.removeBox(boxId)).called(1);
      });

      test('should return ServerFailure on exception', () async {
        when(() => mockRemote.removeBox(boxId)).thenThrow(Exception('delete failed'));

        final result = await repository.removeBox(boxId);

        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<ServerFailure>());
        }, (_) => fail('should fail'));
      });
    });

    group('getUserBoxes', () {
      test('should return list of Box on success', () async {
        when(() => mockLocal.getCachedUserId()).thenAnswer((_) async => userId);
        when(() => mockRemote.getUserBoxes(userId)).thenAnswer((_) async => [mockBoxJson]);

        final result = await repository.getUserBoxes();

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (list) {
          expect(list.length, 1);
          expect(list.first.id, boxId);
        });
      });

      test('should return SessionExpiredFailure when no cached user ID', () async {
        when(() => mockLocal.getCachedUserId()).thenAnswer((_) async => null);

        final result = await repository.getUserBoxes();

        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<SessionExpiredFailure>());
        }, (_) => fail('should fail'));
      });

      test('should return ServerFailure on exception', () async {
        when(() => mockLocal.getCachedUserId()).thenAnswer((_) async => userId);
        when(() => mockRemote.getUserBoxes(userId)).thenThrow(Exception('network error'));

        final result = await repository.getUserBoxes();

        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<ServerFailure>());
        }, (_) => fail('should fail'));
      });
    });

    group('pairBoxWithUid', () {
      test('should return paired Box on success', () async {
        when(() => mockLocal.getCachedUserId()).thenAnswer((_) async => userId);
        when(() => mockRemote.findBoxByUid(uidHardware)).thenAnswer((_) async => null);
        when(() => mockRemote.pairBox(boxId, uidHardware, userId)).thenAnswer((_) async => mockBoxJson);

        final result = await repository.pairBoxWithUid(boxId, uidHardware, signature);

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (box) {
          expect(box.id, boxId);
        });
      });

      test('should return SessionExpiredFailure when no cached user ID', () async {
        when(() => mockLocal.getCachedUserId()).thenAnswer((_) async => null);

        final result = await repository.pairBoxWithUid(boxId, uidHardware, signature);

        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<SessionExpiredFailure>());
        }, (_) => fail('should fail'));
      });

      test('should return DeviceAlreadyAssignedFailure if box belongs to another user', () async {
        when(() => mockLocal.getCachedUserId()).thenAnswer((_) async => userId);
        when(() => mockRemote.findBoxByUid(uidHardware)).thenAnswer((_) async => {
          'id': boxId,
          'user_id': 'other-user-456',
        });

        final result = await repository.pairBoxWithUid(boxId, uidHardware, signature);

        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<DeviceAlreadyAssignedFailure>());
        }, (_) => fail('should fail'));
      });

      test('should return DeviceNotIdentifiedFailure on generic exception', () async {
        when(() => mockLocal.getCachedUserId()).thenAnswer((_) async => userId);
        when(() => mockRemote.findBoxByUid(uidHardware)).thenThrow(Exception('unknown'));

        final result = await repository.pairBoxWithUid(boxId, uidHardware, signature);

        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<DeviceNotIdentifiedFailure>());
        }, (_) => fail('should fail'));
      });
    });

    group('identifyBox', () {
      test('should return Box on success', () async {
        when(() => mockRemote.findBoxByUid(uidHardware)).thenAnswer((_) async => mockBoxJson);

        final result = await repository.identifyBox(uidHardware);

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (box) {
          expect(box.uidHardware, uidHardware);
        });
      });

      test('should return DeviceNotFoundFailure when box is null', () async {
        when(() => mockRemote.findBoxByUid(uidHardware)).thenAnswer((_) async => null);

        final result = await repository.identifyBox(uidHardware);

        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<DeviceNotFoundFailure>());
        }, (_) => fail('should fail'));
      });

      test('should return ServerFailure on exception', () async {
        when(() => mockRemote.findBoxByUid(uidHardware)).thenThrow(Exception('server down'));

        final result = await repository.identifyBox(uidHardware);

        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<ServerFailure>());
        }, (_) => fail('should fail'));
      });
    });
  });
}
