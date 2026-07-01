import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/repositories/box_repository.dart';
import 'package:aricie/domain/usecases/devices/add_device.dart';
import 'package:aricie/domain/usecases/devices/remove_device.dart';
import 'package:aricie/domain/usecases/devices/get_user_devices.dart';
import 'package:dartz/dartz.dart';

Box _box({String id = 'box-1', String name = 'Boîtier salon'}) {
  return Box(
    id: id,
    uidHardware: 'ESP32-A1B2C3D4',
    name: name,
    userId: 'user-1',
    status: BoxStatus.active,
    createdAt: DateTime(2026, 1, 1),
  );
}

class MockBoxRepository implements BoxRepository {
  @override
  Future<Either<Failure, Box>> addBox(String name, String? location) async {
    if (name.trim().isEmpty) {
      return Left<Failure, Box>(const ServerFailure('Nom requis'));
    }
    return Right<Failure, Box>(_box(name: name));
  }

  @override
  Future<Either<Failure, void>> removeBox(String boxId) async {
    if (boxId == 'unknown') {
      return Left<Failure, void>(const DeviceNotFoundFailure());
    }
    return const Right<Failure, void>(null);
  }

  @override
  Future<Either<Failure, List<Box>>> getUserBoxes() async {
    return Right<Failure, List<Box>>([_box(), _box(id: 'box-2', name: 'Boîtier cuisine')]);
  }

  @override
  Future<Either<Failure, Box>> pairBoxWithUid(String boxId, String uidHardware, String signature) async {
    return Right<Failure, Box>(_box(id: boxId));
  }

  @override
  Future<Either<Failure, Box>> identifyBox(String uidHardware) async {
    return Right<Failure, Box>(_box());
  }
}

void main() {
  late MockBoxRepository repo;

  setUp(() => repo = MockBoxRepository());

  group('AddDevice', () {
    test('ajoute un boîtier avec un nom valide', () async {
      final result = await AddDevice(repo).call('Boîtier chambre', 'Chambre');
      expect(result.isRight(), true);
      result.fold((_) {}, (b) => expect(b.name, 'Boîtier chambre'));
    });

    test('renvoie une Failure pour un nom vide', () async {
      final result = await AddDevice(repo).call('  ', 'Salon');
      expect(result.isLeft(), true);
    });
  });

  group('RemoveDevice', () {
    test('supprime un boîtier existant', () async {
      final result = await RemoveDevice(repo).call('box-1');
      expect(result.isRight(), true);
    });

    test('renvoie DeviceNotFoundFailure pour un boîtier inconnu', () async {
      final result = await RemoveDevice(repo).call('unknown');
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<DeviceNotFoundFailure>()), (_) {});
    });
  });

  group('GetUserDevices', () {
    test('renvoie la liste des boîtiers de l\'utilisateur', () async {
      final result = await GetUserDevices(repo).call();
      expect(result.isRight(), true);
      result.fold((_) {}, (list) => expect(list.length, 2));
    });
  });
}
