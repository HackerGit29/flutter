import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/repositories/box_repository.dart';
import 'package:dartz/dartz.dart';

class PairDeviceWithUid {
  final BoxRepository _repository;
  PairDeviceWithUid(this._repository);

  Future<Either<Failure, Box>> call(String boxId, String uidHardware, String signature) {
    return _repository.pairBoxWithUid(boxId, uidHardware, signature);
  }
}
