import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/admin_action.dart';
import 'package:aricie/domain/entities/appliance.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

// ─── Fixtures ────────────────────────────────────────────────────────────────

final kAdminUser = User(
  id: 'admin-1',
  email: 'admin@test.com',
  role: Role.admin,
  status: UserStatus.active,
  createdAt: DateTime(2026, 1, 1),
);

final kRegularUser = User(
  id: 'user-1',
  email: 'user@test.com',
  role: Role.user,
  status: UserStatus.active,
  createdAt: DateTime(2026, 1, 1),
);

final kSuspendedUser = User(
  id: 'user-2',
  email: 'suspended@test.com',
  role: Role.user,
  status: UserStatus.suspended,
  createdAt: DateTime(2026, 1, 1),
);

final kVipUser = User(
  id: 'user-3',
  email: 'vip@test.com',
  role: Role.vip,
  status: UserStatus.active,
  createdAt: DateTime(2026, 1, 1),
);

final kOtherAdmin = User(
  id: 'admin-2',
  email: 'admin2@test.com',
  role: Role.admin,
  status: UserStatus.active,
  createdAt: DateTime(2026, 1, 1),
);

final kBox = Box(
  id: 'box-1',
  name: 'Boîtier Test',
  uidHardware: 'ESP32-ABCDEF01',
  userId: 'user-1',
  location: 'Salon',
  status: BoxStatus.active,
  createdAt: DateTime(2026, 1, 1),
);

final kSubscription = Subscription(
  id: 'sub-1',
  userId: 'user-1',
  type: SubscriptionType.vip,
  isActive: true,
  autoRenew: true,
  createdAt: DateTime(2026, 1, 1),
  endDate: DateTime(2027, 1, 1),
  startDate: DateTime(2026, 1, 1),
);

// ─── Mock Auth Repository ────────────────────────────────────────────────────

class MockAuthRepo implements AuthRepository {
  final User? currentUser;
  MockAuthRepo({User? user}) : currentUser = user ?? kAdminUser;

  @override
  Future<Either<Failure, User?>> getCurrentUser() async =>
      Right(currentUser);

  @override
  Future<Either<Failure, User>> login(String e, String p) async =>
      Left(const ServerFailure('mock'));
  @override
  Future<Either<Failure, User>> register(String e, String p) async =>
      Left(const ServerFailure('mock'));
  @override
  Future<Either<Failure, void>> logout() async => const Right(null);
  @override
  Future<Either<Failure, String>> refreshToken() async => const Right('');
  @override
  Future<Either<Failure, void>> resetPassword(String email) async =>
      const Right(null);
  @override
  Future<Either<Failure, void>> confirmPasswordReset(
          String email, String token, String newPassword) async =>
      const Right(null);
  @override
  Future<Either<Failure, void>> changePassword(
          String currentPassword, String newPassword) async =>
      const Right(null);
}

// ─── Mock Admin Repository ───────────────────────────────────────────────────

class MockAdminRepo implements AdminRepository {
  // Configurable responses
  User? getUserResult;
  bool getUserFails;
  bool operationFails;

  MockAdminRepo({
    this.getUserResult,
    this.getUserFails = false,
    this.operationFails = false,
  }) {
    getUserResult ??= kRegularUser;
  }

  @override
  Future<Either<Failure, User>> getUser(String userId) async {
    if (getUserFails) return Left(const ServerFailure('user not found'));
    return Right(getUserResult!);
  }

  @override
  Future<Either<Failure, User>> suspendUser(String userId) async {
    if (operationFails) return Left(const ServerFailure('suspend failed'));
    return Right(kRegularUser.copyWith(status: UserStatus.suspended));
  }

  @override
  Future<Either<Failure, User>> activateUser(String userId) async {
    if (operationFails) return Left(const ServerFailure('activate failed'));
    return Right(kSuspendedUser.copyWith(status: UserStatus.active));
  }

  @override
  Future<Either<Failure, User>> assignRole(String userId, String role) async {
    if (operationFails) return Left(const ServerFailure('assign role failed'));
    return Right(kRegularUser.copyWith(role: Role.values.byName(role)));
  }

  @override
  Future<Either<Failure, List<User>>> getAllUsers() async =>
      Right([kRegularUser, kVipUser]);

  @override
  Future<Either<Failure, List<Box>>> getAllBoxes() async => Right([kBox]);

  @override
  Future<Either<Failure, Box>> createBox({
    required String uidHardware,
    required String name,
    String? location,
    String? userId,
  }) async {
    if (operationFails) return Left(const ServerFailure('create box failed'));
    return Right(Box(
      id: 'box-new',
      name: name,
      uidHardware: uidHardware,
      userId: userId ?? 'user-1',
      location: location ?? 'Salon',
      status: BoxStatus.active,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<Either<Failure, List<Appliance>>> createAppliancesForBox(
      String boxId, String userId) async {
    if (operationFails) return Left(const ServerFailure('mock'));
    return Right(List.generate(
      3,
      (i) => Appliance(
        id: 'app-$i',
        boxId: boxId,
        userId: userId,
        relayIndex: i + 1,
        name: 'Appareil ${i + 1}',
        isOn: false, createdAt: DateTime(2026, 1, 1),
      ),
    ));
  }

  @override
  Future<Either<Failure, Box>> assignBox(
          String boxId, String newUserId) async =>
      Left(const ServerFailure('mock'));

  @override
  Future<Either<Failure, Box>> overrideOwnership(
          String boxId, String newUserId) async =>
      Left(const ServerFailure('mock'));

  @override
  Future<Either<Failure, Box>> resetBox(String boxId) async {
    if (operationFails) return Left(const ServerFailure('reset failed'));
    return Right(kBox);
  }

  @override
  Future<Either<Failure, SyncLog>> forceSync(String boxId) async =>
      Left(const ServerFailure('mock'));

  @override
  Future<Either<Failure, List<Subscription>>> getAllSubscriptions() async =>
      Right([kSubscription]);

  @override
  Future<Either<Failure, Subscription>> activateSubscription(
      String subscriptionId) async {
    if (operationFails) return Left(const ServerFailure('mock'));
    return Right(kSubscription);
  }

  @override
  Future<Either<Failure, Subscription>> revokeSubscription(
      String subscriptionId) async {
    if (operationFails) return Left(const ServerFailure('mock'));
    return Right(Subscription(
      id: kSubscription.id,
      userId: kSubscription.userId,
      type: kSubscription.type,
      startDate: kSubscription.startDate,
      endDate: DateTime.now(),
      isActive: false,
      autoRenew: false,
      createdAt: kSubscription.createdAt,
    ));
  }

  @override
  Future<Either<Failure, List<Box>>> getAvailableBoxes() async =>
      Right([kBox]);

  @override
  Future<Either<Failure, void>> logAdminAction({
    required String adminId,
    required String action,
    required String targetType,
    required String targetId,
    Map<String, dynamic>? details,
  }) async =>
      const Right(null);

  @override
  Future<Either<Failure, List<AdminAction>>> getAdminActions(
          {int limit = 50}) async =>
      const Right([]);

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getDeviceCommands(
          {int limit = 50}) async =>
      const Right([]);

  @override
  Future<Either<Failure, List<SyncLog>>> getSyncLogs(
          {String? userId, String? boxId}) async =>
      const Right([]);
}
