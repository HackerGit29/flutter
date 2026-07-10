import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:aricie/data/datasources/supabase_sync_datasource.dart';
import 'package:aricie/data/repositories/sync_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseSyncDataSource extends Mock implements SupabaseSyncDataSource {}

void main() {
  late MockSupabaseSyncDataSource mockDataSource;
  late SyncRepositoryImpl repository;

  setUp(() {
    mockDataSource = MockSupabaseSyncDataSource();
    repository = SyncRepositoryImpl(mockDataSource);
  });

  group('SyncRepositoryImpl', () {
    const boxId = 'box-123';
    const userId = 'user-456';
    final timestamp = DateTime(2026, 1, 1).toIso8601String();

    group('requestSync', () {
      test('should return SyncLog when datasource updateLastSync and createSyncLog succeed', () async {
        when(() => mockDataSource.updateLastSync(boxId)).thenAnswer((_) async => {});
        when(() => mockDataSource.createSyncLog(any())).thenAnswer((_) async => {
          'id': 'log-1',
          'box_id': boxId,
          'user_id': userId,
          'status': 'success',
          'timestamp': timestamp,
        });

        final result = await repository.requestSync(boxId);

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (log) {
          expect(log.id, 'log-1');
          expect(log.boxId, boxId);
          expect(log.status, SyncStatus.success);
        });
      });

      test('should return ServerFailure when datasource call fails', () async {
        when(() => mockDataSource.updateLastSync(boxId)).thenThrow(Exception('database error'));

        final result = await repository.requestSync(boxId);

        expect(result.isLeft(), true);
        result.fold((failure) => expect(failure, isA<ServerFailure>()), (_) => fail('should fail'));
      });
    });

    group('validateBoxOwnership', () {
      test('should return true when datasource verifyOwnership returns true', () async {
        when(() => mockDataSource.verifyOwnership(boxId, userId)).thenAnswer((_) async => true);

        final result = await repository.validateBoxOwnership(boxId, userId);

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (val) => expect(val, true));
      });

      test('should return false when datasource verifyOwnership fails', () async {
        when(() => mockDataSource.verifyOwnership(boxId, userId)).thenThrow(Exception('error'));

        final result = await repository.validateBoxOwnership(boxId, userId);

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (val) => expect(val, false));
      });
    });

    group('verifyBoxCryptoUid', () {
      test('should return true when box exists', () async {
        when(() => mockDataSource.getBoxById(boxId)).thenAnswer((_) async => {'id': boxId});

        final result = await repository.verifyBoxCryptoUid(boxId, 'sig', 'nonce');

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (val) => expect(val, true));
      });

      test('should return false when box is null', () async {
        when(() => mockDataSource.getBoxById(boxId)).thenAnswer((_) async => null);

        final result = await repository.verifyBoxCryptoUid(boxId, 'sig', 'nonce');

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (val) => expect(val, false));
      });

      test('should return false when datasource fails', () async {
        when(() => mockDataSource.getBoxById(boxId)).thenThrow(Exception('error'));

        final result = await repository.verifyBoxCryptoUid(boxId, 'sig', 'nonce');

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (val) => expect(val, false));
      });
    });

    group('logSyncResult', () {
      test('should create sync log and return SyncLog entity', () async {
        when(() => mockDataSource.createSyncLog(any())).thenAnswer((_) async => {
          'id': 'log-2',
          'box_id': boxId,
          'user_id': userId,
          'status': 'failed',
          'timestamp': timestamp,
        });

        final result = await repository.logSyncResult(boxId, userId, 'failed', {'error': 'timeout'});

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (log) {
          expect(log.id, 'log-2');
          expect(log.status, SyncStatus.failed);
        });
      });

      test('should return ServerFailure when datasource call fails', () async {
        when(() => mockDataSource.createSyncLog(any())).thenThrow(Exception('error'));

        final result = await repository.logSyncResult(boxId, userId, 'failed', null);

        expect(result.isLeft(), true);
        result.fold((failure) => expect(failure, isA<ServerFailure>()), (_) => fail('should fail'));
      });
    });
  });
}
