import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:dartz/dartz.dart';

class GetAvailableBoxes {
  final AdminRepository _adminRepo;
  GetAvailableBoxes(this._adminRepo);

  Future<Either<Failure, List<Box>>> call() async {
    return await _adminRepo.getAvailableBoxes();
  }
}
