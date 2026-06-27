import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/data/datasources/supabase_admin_datasource.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/entities/appliance.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:aricie/domain/entities/admin_action.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:dartz/dartz.dart';

class AdminRepositoryImpl implements AdminRepository {
  final SupabaseAdminDataSource _remote;

  AdminRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<User>>> getAllUsers() async {
    try {
      final data = await _remote.getAllUsers();
      return Right(data.map((json) => User.fromJson(json)).toList());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, User>> getUser(String userId) async {
    try {
      final data = await _remote.getUserById(userId);
      return Right(User.fromJson(data));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, User>> suspendUser(String userId) async {
    try {
      final data = await _remote.updateUserStatus(userId, 'suspended');
      return Right(User.fromJson(data));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, User>> activateUser(String userId) async {
    try {
      final data = await _remote.updateUserStatus(userId, 'active');
      return Right(User.fromJson(data));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, User>> assignRole(String userId, String role) async {
    try {
      final data = await _remote.updateUserRole(userId, role);
      return Right(User.fromJson(data));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<Box>>> getAllBoxes() async {
    try {
      final data = await _remote.getAllBoxes();
      return Right(data.map((json) => Box.fromJson(json)).toList());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<SyncLog>>> getSyncLogs({String? userId, String? boxId}) async {
    try {
      final data = await _remote.getSyncLogs(userId: userId, boxId: boxId);
      return Right(data.map((json) => SyncLog.fromJson(json)).toList());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Box>> assignBox(String boxId, String newUserId) async {
    try {
      final data = await _remote.assignBoxToUser(boxId, newUserId);
      return Right(Box.fromJson(data));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Box>> overrideOwnership(String boxId, String newUserId) async {
    try {
      final data = await _remote.overrideBoxOwnership(boxId, newUserId);
      return Right(Box.fromJson(data));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Box>> resetBox(String boxId) async {
    try {
      final data = await _remote.resetBox(boxId);
      return Right(Box.fromJson(data));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, SyncLog>> forceSync(String boxId) async {
    try {
      final data = await _remote.forceSync(boxId);
      return Right(SyncLog.fromJson(data));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<Subscription>>> getAllSubscriptions() async {
    try {
      final data = await _remote.getAllSubscriptions();
      return Right(data.map((json) => Subscription.fromJson(json)).toList());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Subscription>> activateSubscription(String subscriptionId) async {
    try {
      final data = await _remote.updateSubscription(subscriptionId, {
        'is_active': true,
        'end_date': null,
      });
      return Right(Subscription.fromJson(data));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Subscription>> revokeSubscription(String subscriptionId) async {
    try {
      final data = await _remote.updateSubscription(subscriptionId, {
        'is_active': false,
        'end_date': DateTime.now().toIso8601String(),
      });
      return Right(Subscription.fromJson(data));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<Box>>> getAvailableBoxes() async {
    try {
      final data = await _remote.getAvailableBoxes();
      return Right(data.map((json) => Box.fromJson(json)).toList());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Box>> createBox({
    required String uidHardware,
    required String name,
    String? location,
    String? userId,
  }) async {
    try {
      final data = await _remote.createBox(
        uidHardware: uidHardware,
        name: name,
        location: location,
        userId: userId,
      );
      return Right(Box.fromJson(data));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<Appliance>>> createAppliancesForBox(String boxId, String userId) async {
    try {
      final data = await _remote.createAppliancesForBox(boxId, userId);
      return Right(data.map((json) => Appliance.fromJson(json)).toList());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, void>> logAdminAction({
    required String adminId,
    required String action,
    required String targetType,
    required String targetId,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _remote.logAdminAction({
        'admin_id': adminId,
        'action': action,
        'target_type': targetType,
        'target_id': targetId,
        if (details != null) 'details': details,
      });
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<AdminAction>>> getAdminActions({int limit = 50}) async {
    try {
      final data = await _remote.getAdminActions(limit: limit);
      return Right(data.map((json) => AdminAction.fromJson(json)).toList());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getDeviceCommands({int limit = 50}) async {
    try {
      final data = await _remote.getDeviceCommands(limit: limit);
      return Right(data);
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
