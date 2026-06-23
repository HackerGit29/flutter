import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/repositories/box_repository.dart';
import 'package:dartz/dartz.dart';

class AddDevice {
  final BoxRepository _repository;
  AddDevice(this._repository);

  Future<Either<Failure, Box>> call(String name, String location) {
    return _repository.addBox(name, location);
  }
}
