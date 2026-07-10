import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/repositories/sync_repository.dart';
import 'package:aricie/domain/repositories/box_repository.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:aricie/domain/usecases/sync/log_sync_result.dart';
import 'package:aricie/domain/usecases/sync/request_sync.dart';
import 'package:aricie/domain/usecases/sync/validate_device_ownership.dart';
import 'package:aricie/domain/usecases/sync/verify_device_crypto_uid.dart';
import 'package:dartz/dartz.dart';

class FakeSyncRepository implements SyncRepository {
  bool validateOwnershipResult = true;
  bool verifyCryptoResult = true;
  bool requestSyncFails = false;
  SyncLog? loggedSyncResult;

  @override
  Future<Either<Failure, SyncLog>> requestSync(String boxId) async {
    if (requestSyncFails) return Left(const ServerFailure());
    return Right(SyncLog(
      id: 'sync-123',
      boxId: boxId,
      userId: 'user-123',
      status: SyncStatus.success,
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<Either<Failure, bool>> validateBoxOwnership(String boxId, String userId) async {
    return Right(validateOwnershipResult);
  }

  @override
  Future<Either<Failure, bool>> verifyBoxCryptoUid(String boxId, String signature, String nonce) async {
    return Right(verifyCryptoResult);
  }

  @override
  Future<Either<Failure, SyncLog>> logSyncResult(String boxId, String userId, String status, Map<String, dynamic>? data) async {
    final log = SyncLog(
      id: 'sync-log-999',
      boxId: boxId,
      userId: userId,
      status: SyncStatus.values.firstWhere((e) => e.name == status, orElse: () => SyncStatus.failed),
      data: data,
      timestamp: DateTime.now(),
    );
    loggedSyncResult = log;
    return Right(log);
  }
}

class FakeBoxRepositoryForSync implements BoxRepository {
  List<Box> boxes = [];

  @override
  Future<Either<Failure, Box>> addBox(String name, String? location) async => Left(const ServerFailure());
  @override
  Future<Either<Failure, void>> removeBox(String boxId) async => Left(const ServerFailure());
  @override
  Future<Either<Failure, Box>> pairBoxWithUid(String boxId, String uidHardware, String signature) async => Left(const ServerFailure());
  @override
  Future<Either<Failure, Box>> identifyBox(String uidHardware) async => Left(const ServerFailure());

  @override
  Future<Either<Failure, List<Box>>> getUserBoxes() async {
    return Right(boxes);
  }
}

class FakeAuthRepositoryForSync implements AuthRepository {
  User? currentUser;

  @override
  Future<Either<Failure, User?>> getCurrentUser() async => Right(currentUser);

  @override
  Future<Either<Failure, User>> login(String email, String password) async => Left(const ServerFailure());
  @override
  Future<Either<Failure, User>> register(String email, String password) async => Left(const ServerFailure());
  @override
  Future<Either<Failure, void>> logout() async => const Right(null);
  @override
  Future<Either<Failure, String>> refreshToken() async => const Right('');
  @override
  Future<Either<Failure, void>> resetPassword(String email) async => const Right(null);
  @override
  Future<Either<Failure, void>> confirmPasswordReset(String email, String token, String newPassword) async => const Right(null);
  @override
  Future<Either<Failure, void>> changePassword(String currentPassword, String newPassword) async => const Right(null);
}

void main() {
  group('Sync Use Cases', () {
    late FakeSyncRepository syncRepo;
    late FakeBoxRepositoryForSync boxRepo;
    late FakeAuthRepositoryForSync authRepo;

    setUp(() {
      syncRepo = FakeSyncRepository();
      boxRepo = FakeBoxRepositoryForSync();
      authRepo = FakeAuthRepositoryForSync();
    });

    group('LogSyncResult', () {
      test('should log sync result correctly', () async {
        final usecase = LogSyncResult(syncRepo);
        final result = await usecase.call('box-123', 'user-456', 'success', {'info': 'test'});

        expect(result.isRight(), true);
        expect(syncRepo.loggedSyncResult, isNotNull);
        expect(syncRepo.loggedSyncResult!.boxId, 'box-123');
        expect(syncRepo.loggedSyncResult!.userId, 'user-456');
        expect(syncRepo.loggedSyncResult!.status, SyncStatus.success);
      });
    });

    group('ValidateDeviceOwnership', () {
      test('should call validateBoxOwnership', () async {
        final usecase = ValidateDeviceOwnership(syncRepo);
        final result = await usecase.call('box-123', 'user-456');

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (val) => expect(val, true));
      });
    });

    group('VerifyDeviceCryptoUid', () {
      test('should call verifyBoxCryptoUid', () async {
        final usecase = VerifyDeviceCryptoUid(syncRepo);
        final result = await usecase.call('box-123', 'signature-abc', 'nonce-xyz');

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (val) => expect(val, true));
      });
    });

    group('RequestSync', () {
      late RequestSync usecase;
      final testUser = User(
        id: 'user-123',
        email: 'test@aricie.com',
        role: Role.user,
        status: UserStatus.active,
        createdAt: DateTime.now(),
      );
      final testBox = Box(
        id: 'box-123',
        uidHardware: 'ESP32-12345678',
        name: 'My Box',
        userId: 'user-123',
        status: BoxStatus.active,
        createdAt: DateTime.now(),
      );

      setUp(() {
        usecase = RequestSync(syncRepo, boxRepo, authRepo);
        authRepo.currentUser = testUser;
        boxRepo.boxes = [testBox];
      });

      test('should return SessionExpiredFailure when user is not logged in', () async {
        authRepo.currentUser = null;
        final result = await usecase.call('box-123');

        expect(result.isLeft(), true);
        result.fold((f) => expect(f, isA<SessionExpiredFailure>()), (_) => fail('should fail'));
      });

      test('should return SyncUnauthorizedFailure when user does not own the box', () async {
        syncRepo.validateOwnershipResult = false;
        final result = await usecase.call('box-123');

        expect(result.isLeft(), true);
        result.fold((f) => expect(f, isA<SyncUnauthorizedFailure>()), (_) => fail('should fail'));
        expect(syncRepo.loggedSyncResult, isNotNull);
        expect(syncRepo.loggedSyncResult!.status, SyncStatus.unauthorized);
      });

      test('should return DeviceNotFoundFailure when box is not in user boxes list', () async {
        boxRepo.boxes = [];
        final result = await usecase.call('box-123');

        expect(result.isLeft(), true);
        result.fold((f) => expect(f, isA<DeviceNotFoundFailure>()), (_) => fail('should fail'));
      });

      test('should return DeviceBlockedFailure when box is blocked', () async {
        final blockedBox = Box(
          id: 'box-123',
          uidHardware: 'ESP-123',
          name: 'Box',
          userId: 'user-123',
          status: BoxStatus.blocked,
          createdAt: DateTime.now(),
        );
        boxRepo.boxes = [blockedBox];

        final result = await usecase.call('box-123');

        expect(result.isLeft(), true);
        result.fold((f) => expect(f, isA<DeviceBlockedFailure>()), (_) => fail('should fail'));
      });

      test('should request sync and return success when box is valid', () async {
        final result = await usecase.call('box-123');

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (log) {
          expect(log.boxId, 'box-123');
          expect(log.status, SyncStatus.success);
        });
      });
    });
  });
}
