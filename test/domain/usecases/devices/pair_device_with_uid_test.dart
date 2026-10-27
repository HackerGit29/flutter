import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/repositories/box_repository.dart';
import 'package:aricie/domain/usecases/devices/pair_device_with_uid.dart';
import 'package:dartz/dartz.dart';

class FakeBoxRepository implements BoxRepository {
  bool failPairing = false;

  @override
  Future<Either<Failure, Box>> addBox(String name, String? location) async => Left(const ServerFailure());

  @override
  Future<Either<Failure, void>> removeBox(String boxId) async => Left(const ServerFailure());

  @override
  Future<Either<Failure, List<Box>>> getUserBoxes() async => Left(const ServerFailure());

  @override
  Future<Either<Failure, Box>> identifyBox(String uidHardware) async => Left(const ServerFailure());

  @override
  Future<Either<Failure, Box>> pairBoxWithUid(String boxId, String uidHardware, String signature) async {
    if (failPairing) {
      return Left(const DeviceCryptoMismatchFailure());
    }
    return Right(Box(
      id: boxId,
      uidHardware: uidHardware,
      name: 'Paired Box',
      userId: 'user-1',
      status: BoxStatus.active,
      createdAt: DateTime(2026, 1, 1),
    ));
  }
}

void main() {
  late FakeBoxRepository repo;
  late PairDeviceWithUid usecase;

  setUp(() {
    repo = FakeBoxRepository();
    usecase = PairDeviceWithUid(repo);
  });

  group('PairDeviceWithUid', () {
    test('should return paired box when repository succeeds', () async {
      final result = await usecase.call('box-123', 'ESP32-12345678', 'valid-sig');

      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('should not return failure'),
        (box) {
          expect(box.id, 'box-123');
          expect(box.uidHardware, 'ESP32-12345678');
          expect(box.status, BoxStatus.active);
        },
      );
    });

    test('should return failure when repository fails', () async {
      repo.failPairing = true;
      final result = await usecase.call('box-123', 'ESP32-12345678', 'invalid-sig');

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<DeviceCryptoMismatchFailure>()),
        (_) => fail('should not return right'),
      );
    });
  });
}
