import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/device.dart';
import 'package:aricie/domain/repositories/device_repository.dart';
import 'package:dartz/dartz.dart';

class PairDeviceWithUid {
  final DeviceRepository _repository;
  PairDeviceWithUid(this._repository);

  Future<Either<Failure, Device>> call(String deviceId, String uidHardware, String signature) {
    return _repository.pairDeviceWithUid(deviceId, uidHardware, signature);
  }
}
