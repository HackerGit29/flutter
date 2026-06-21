import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/repositories/device_repository.dart';
import 'package:dartz/dartz.dart';

class RemoveDevice {
  final DeviceRepository _repository;
  RemoveDevice(this._repository);

  Future<Either<Failure, void>> call(String deviceId) {
    return _repository.removeDevice(deviceId);
  }
}
