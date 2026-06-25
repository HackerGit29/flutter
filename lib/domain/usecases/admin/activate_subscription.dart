import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class ActivateSubscription {
  final AdminRepository _adminRepo;
  final AuthRepository _authRepo;
  ActivateSubscription(this._adminRepo, this._authRepo);

  Future<Either<Failure, Subscription>> call(String subscriptionId) async {
    final currentUser = await _authRepo.getCurrentUser();
    final user = currentUser.getOrElse(() => null);
    if (user == null || !user.isAdmin) return Left(AdminPermissionFailure());

    final result = await _adminRepo.activateSubscription(subscriptionId);
    if (result.isRight()) {
      await _adminRepo.logAdminAction(
        adminId: user.id,
        action: 'activate_license',
        targetType: 'subscription',
        targetId: subscriptionId,
      );
    }
    return result;
  }
}
