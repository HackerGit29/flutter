import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/entities/appliance.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:aricie/domain/entities/admin_action.dart';
import 'package:dartz/dartz.dart';

abstract class AdminRepository {
  Future<Either<Failure, List<User>>> getAllUsers();
  Future<Either<Failure, User>> getUser(String userId);
  Future<Either<Failure, User>> suspendUser(String userId);
  Future<Either<Failure, User>> activateUser(String userId);
  Future<Either<Failure, User>> assignRole(String userId, String role);
  Future<Either<Failure, List<Box>>> getAllBoxes();
  Future<Either<Failure, List<SyncLog>>> getSyncLogs({String? userId, String? boxId});
  Future<Either<Failure, Box>> assignBox(String boxId, String newUserId);
  Future<Either<Failure, Box>> overrideOwnership(String boxId, String newUserId);
  Future<Either<Failure, Box>> resetBox(String boxId);
  Future<Either<Failure, SyncLog>> forceSync(String boxId);
  Future<Either<Failure, List<Subscription>>> getAllSubscriptions();
  Future<Either<Failure, Subscription>> activateSubscription(String subscriptionId);
  Future<Either<Failure, Subscription>> revokeSubscription(String subscriptionId);
  Future<Either<Failure, List<Box>>> getAvailableBoxes();
  Future<Either<Failure, Box>> createBox({
    required String uidHardware,
    required String name,
    String? location,
    String? userId,
  });
  Future<Either<Failure, List<Appliance>>> createAppliancesForBox(String boxId, String userId);
  Future<Either<Failure, void>> logAdminAction({
    required String adminId,
    required String action,
    required String targetType,
    required String targetId,
    Map<String, dynamic>? details,
  });
  Future<Either<Failure, List<AdminAction>>> getAdminActions({int limit = 50});
  Future<Either<Failure, List<Map<String, dynamic>>>> getDeviceCommands({int limit = 50});
}
