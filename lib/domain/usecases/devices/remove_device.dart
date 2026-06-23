import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/repositories/box_repository.dart';
import 'package:dartz/dartz.dart';

class RemoveDevice {
  final BoxRepository _repository;
  RemoveDevice(this._repository);

  Future<Either<Failure, void>> call(String boxId) {
    return _repository.removeBox(boxId);
  }
}
