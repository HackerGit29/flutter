import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:dartz/dartz.dart';

abstract class BoxRepository {
  Future<Either<Failure, Box>> addBox(String name, String? location);
  Future<Either<Failure, void>> removeBox(String boxId);
  Future<Either<Failure, List<Box>>> getUserBoxes();
  Future<Either<Failure, Box>> pairBoxWithUid(String boxId, String uidHardware, String signature);
  Future<Either<Failure, Box>> identifyBox(String uidHardware);
}
