import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/appliance.dart';
import 'package:aricie/domain/repositories/appliance_repository.dart';
import 'package:aricie/domain/usecases/devices/get_user_appliances.dart';
import 'package:aricie/domain/usecases/devices/toggle_device.dart';
import 'package:aricie/domain/usecases/devices/rename_appliance.dart';
import 'package:dartz/dartz.dart';

Appliance _appliance({
  String id = 'app-1',
  String name = 'Chauffe-eau',
  bool isOn = false,
}) {
  return Appliance(
    id: id,
    boxId: 'box-1',
    userId: 'user-1',
    relayIndex: 0,
    name: name,
    isOn: isOn,
    createdAt: DateTime(2026, 1, 1),
  );
}

class MockApplianceRepository implements ApplianceRepository {
  @override
  Future<Either<Failure, List<Appliance>>> getUserAppliances() async {
    return Right<Failure, List<Appliance>>([_appliance(), _appliance(id: 'app-2', name: 'TV')]);
  }

  @override
  Future<Either<Failure, List<Appliance>>> getBoxAppliances(String boxId) async {
    return Right<Failure, List<Appliance>>([_appliance()]);
  }

  @override
  Future<Either<Failure, Appliance>> renameAppliance(String applianceId, String name) async {
    if (name.trim().isEmpty) {
      return Left<Failure, Appliance>(const ServerFailure('Nom invalide'));
    }
    return Right<Failure, Appliance>(_appliance(id: applianceId, name: name));
  }

  @override
  Future<Either<Failure, Appliance>> toggleAppliance(String applianceId, bool on) async {
    if (applianceId == 'unknown') {
      return Left<Failure, Appliance>(const DeviceNotFoundFailure());
    }
    return Right<Failure, Appliance>(_appliance(id: applianceId, isOn: on));
  }
}

void main() {
  late MockApplianceRepository repo;

  setUp(() => repo = MockApplianceRepository());

  group('GetUserAppliances', () {
    test('renvoie la liste des appareils de l\'utilisateur', () async {
      final result = await GetUserAppliances(repo).call();
      expect(result.isRight(), true);
      result.fold((_) {}, (list) => expect(list.length, 2));
    });
  });

  group('ToggleDevice', () {
    test('allume l\'appareil (isOn = true)', () async {
      final result = await ToggleDevice(repo).call('app-1', true);
      expect(result.isRight(), true);
      result.fold((_) {}, (a) => expect(a.isOn, true));
    });

    test('éteint l\'appareil (isOn = false)', () async {
      final result = await ToggleDevice(repo).call('app-1', false);
      result.fold((_) {}, (a) => expect(a.isOn, false));
    });

    test('renvoie DeviceNotFoundFailure pour un appareil inconnu', () async {
      final result = await ToggleDevice(repo).call('unknown', true);
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<DeviceNotFoundFailure>()), (_) {});
    });
  });

  group('RenameAppliance', () {
    test('renomme l\'appareil', () async {
      final result = await RenameAppliance(repo).call('app-1', 'Radiateur');
      expect(result.isRight(), true);
      result.fold((_) {}, (a) => expect(a.name, 'Radiateur'));
    });

    test('renvoie une Failure pour un nom vide', () async {
      final result = await RenameAppliance(repo).call('app-1', '  ');
      expect(result.isLeft(), true);
    });
  });
}
