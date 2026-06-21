import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/device.dart';
import 'package:aricie/domain/repositories/device_repository.dart';
import 'package:dartz/dartz.dart';

class AddDevice {
  final DeviceRepository _repository;
  AddDevice(this._repository);

  Future<Either<Failure, Device>> call(String name, String location) {
    return _repository.addDevice(name, location);
  }
}
