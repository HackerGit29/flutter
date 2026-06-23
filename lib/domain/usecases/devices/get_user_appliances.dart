import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/appliance.dart';
import 'package:aricie/domain/repositories/appliance_repository.dart';
import 'package:dartz/dartz.dart';

class GetUserAppliances {
  final ApplianceRepository _repository;
  GetUserAppliances(this._repository);

  Future<Either<Failure, List<Appliance>>> call() {
    return _repository.getUserAppliances();
  }
}
