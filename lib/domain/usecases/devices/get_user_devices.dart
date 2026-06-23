import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/repositories/box_repository.dart';
import 'package:dartz/dartz.dart';

class GetUserDevices {
  final BoxRepository _repository;
  GetUserDevices(this._repository);

  Future<Either<Failure, List<Box>>> call() {
    return _repository.getUserBoxes();
  }
}
