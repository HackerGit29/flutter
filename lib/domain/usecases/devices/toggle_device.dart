import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/appliance.dart';
import 'package:aricie/domain/repositories/appliance_repository.dart';
import 'package:dartz/dartz.dart';

class ToggleDevice {
  final ApplianceRepository _repository;
  ToggleDevice(this._repository);

  Future<Either<Failure, Appliance>> call(String applianceId, bool on) {
    return _repository.toggleAppliance(applianceId, on);
  }
}
