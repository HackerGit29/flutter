import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/admin_action.dart';
import 'package:aricie/domain/entities/appliance.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:aricie/domain/usecases/admin/get_device_commands.dart';
import 'package:dartz/dartz.dart';

class MockDevCmdRepo implements AdminRepository {
  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getDeviceCommands({int limit = 50}) async {
    return Right<Failure, List<Map<String, dynamic>>>([
      {'id': 'cmd-1', 'user_id': 'u1', 'action': 'on', 'status': 'pending', 'appliance_name': 'chauffe-eau'},
      {'id': 'cmd-2', 'user_id': 'u1', 'action': 'off', 'status': 'acknowledged', 'appliance_name': 'lampe'},
    ]);
  }

  @override
  Future<Either<Failure, List<AdminAction>>> getAdminActions({int limit = 50}) async => const Right<Failure, List<AdminAction>>([]);
  @override
  Future<Either<Failure, List<User>>> getAllUsers() async => const Right<Failure, List<User>>([]);
  @override
  Future<Either<Failure, User>> getUser(String userId) async => Left<Failure, User>(const ServerFailure('mock'));
  @override
  Future<Either<Failure, User>> suspendUser(String userId) async => Left<Failure, User>(const ServerFailure('mock'));
  @override
  Future<Either<Failure, User>> activateUser(String userId) async => Left<Failure, User>(const ServerFailure('mock'));
  @override
  Future<Either<Failure, User>> assignRole(String userId, String role) async => Left<Failure, User>(const ServerFailure('mock'));
  @override
  Future<Either<Failure, List<Box>>> getAllBoxes() async => const Right<Failure, List<Box>>([]);
  @override
  Future<Either<Failure, List<SyncLog>>> getSyncLogs({String? userId, String? boxId}) async => const Right<Failure, List<SyncLog>>([]);
  @override
  Future<Either<Failure, Box>> assignBox(String boxId, String newUserId) async => Left<Failure, Box>(const ServerFailure('mock'));
  @override
  Future<Either<Failure, Box>> overrideOwnership(String boxId, String newUserId) async => Left<Failure, Box>(const ServerFailure('mock'));
  @override
  Future<Either<Failure, Box>> resetBox(String boxId) async => Left<Failure, Box>(const ServerFailure('mock'));
  @override
  Future<Either<Failure, SyncLog>> forceSync(String boxId) async => Left<Failure, SyncLog>(const ServerFailure('mock'));
  @override
  Future<Either<Failure, List<Subscription>>> getAllSubscriptions() async => const Right<Failure, List<Subscription>>([]);
  @override
  Future<Either<Failure, Subscription>> activateSubscription(String subscriptionId) async => Left<Failure, Subscription>(const ServerFailure('mock'));
  @override
  Future<Either<Failure, Subscription>> revokeSubscription(String subscriptionId) async => Left<Failure, Subscription>(const ServerFailure('mock'));
  @override
  @override
  Future<Either<Failure, Box>> createBox({required String uidHardware, required String name, String? location, String? userId}) async => Left<Failure, Box>(const ServerFailure('mock'));
  @override
  Future<Either<Failure, List<Box>>> getAvailableBoxes() async => const Right<Failure, List<Box>>([]);
  @override
  Future<Either<Failure, List<Appliance>>> createAppliancesForBox(String boxId, String userId) async => Left<Failure, List<Appliance>>(const ServerFailure('mock'));
  @override
  Future<Either<Failure, void>> logAdminAction({required String adminId, required String action, required String targetType, required String targetId, Map<String, dynamic>? details}) async => const Right<Failure, void>(null);
}

class MockDevCmdAuthRepo implements AuthRepository {
  final bool isAdmin;

  MockDevCmdAuthRepo({this.isAdmin = true});

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    return Right<Failure, User?>(User(
      id: 'admin-1', email: 'admin@test.com',
      role: isAdmin ? Role.admin : Role.user,
      status: UserStatus.active, createdAt: DateTime.now(),
    ));
  }

  @override
  Future<Either<Failure, User>> login(String email, String password) async {
    return Left<Failure, User>(const ServerFailure('mock'));
  }

  @override
  Future<Either<Failure, User>> register(String email, String password) async {
    return Left<Failure, User>(const ServerFailure('mock'));
  }

  @override
  Future<Either<Failure, void>> logout() async => const Right<Failure, void>(null);

  @override
  Future<Either<Failure, String>> refreshToken() async => const Right<Failure, String>('');
}

void main() {
  test('returns device commands for admin user', () async {
    final useCase = GetDeviceCommands(MockDevCmdRepo(), MockDevCmdAuthRepo(isAdmin: true));
    final result = await useCase();
    expect(result.isRight(), true);
    result.fold((_) {}, (commands) {
      expect(commands.length, 2);
      expect(commands[0]['status'], 'pending');
      expect(commands[1]['status'], 'acknowledged');
    });
  });

  test('returns AdminPermissionFailure for non-admin user', () async {
    final useCase = GetDeviceCommands(MockDevCmdRepo(), MockDevCmdAuthRepo(isAdmin: false));
    final result = await useCase();
    expect(result.isLeft(), true);
    result.fold((f) {
      expect(f, isA<AdminPermissionFailure>());
    }, (_) {});
  });
}
