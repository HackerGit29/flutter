import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/repositories/device_repository.dart';
import 'package:dartz/dartz.dart';

class ToggleDevice {
  final DeviceRepository _repository;
  ToggleDevice(this._repository);

  Future<Either<Failure, void>> call(String deviceId, bool on) {
    return _repository.toggleDevice(deviceId, on);
  }
}
