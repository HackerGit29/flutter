import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/device.dart';
import 'package:aricie/domain/repositories/device_repository.dart';
import 'package:dartz/dartz.dart';

class GetUserDevices {
  final DeviceRepository _repository;
  GetUserDevices(this._repository);

  Future<Either<Failure, List<Device>>> call() {
    return _repository.getUserDevices();
  }
}
