import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/appliance.dart';
import 'package:dartz/dartz.dart';

abstract class ApplianceRepository {
  Future<Either<Failure, List<Appliance>>> getUserAppliances();
  Future<Either<Failure, List<Appliance>>> getBoxAppliances(String boxId);
  Future<Either<Failure, Appliance>> renameAppliance(String applianceId, String name);
  Future<Either<Failure, Appliance>> toggleAppliance(String applianceId, bool on);
}
