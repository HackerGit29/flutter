import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/repositories/sync_repository.dart';
import 'package:dartz/dartz.dart';

class VerifyDeviceCryptoUid {
  final SyncRepository _repository;
  VerifyDeviceCryptoUid(this._repository);

  Future<Either<Failure, bool>> call(String deviceId, String signature, String nonce) {
    return _repository.verifyDeviceCryptoUid(deviceId, signature, nonce);
  }
}
