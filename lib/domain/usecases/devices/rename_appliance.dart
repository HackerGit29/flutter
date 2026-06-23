import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/appliance.dart';
import 'package:aricie/domain/repositories/appliance_repository.dart';
import 'package:dartz/dartz.dart';

class RenameAppliance {
  final ApplianceRepository _repository;
  RenameAppliance(this._repository);

  Future<Either<Failure, Appliance>> call(String applianceId, String name) {
    return _repository.renameAppliance(applianceId, name);
  }
}
