import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/appliance.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/entities/energy_data.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/repositories/appliance_repository.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:aricie/domain/repositories/box_repository.dart';
import 'package:aricie/domain/repositories/energy_repository.dart';
import 'package:aricie/domain/repositories/license_repository.dart';
import 'package:aricie/domain/repositories/sync_repository.dart';
import 'package:dartz/dartz.dart';

// ─── Fixtures shared across screen widget tests ─────────────────────────────

final kScreenUser = User(
  id: 'user-1',
  email: 'user@test.com',
  role: Role.user,
  status: UserStatus.active,
  createdAt: DateTime(2026, 1, 1),
);

final kScreenBox = Box(
  id: 'box-1',
  name: 'Boîtier Salon',
  uidHardware: 'ESP32-ABCDEF01',
  userId: 'user-1',
  location: 'Salon',
  status: BoxStatus.active,
  createdAt: DateTime(2026, 1, 1),
);

final kScreenAppliance = Appliance(
  id: 'app-1',
  boxId: 'box-1',
  boxUid: 'ESP32-ABCDEF01',
  userId: 'user-1',
  relayIndex: 1,
  name: 'Réfrigérateur',
  isOn: true,
  createdAt: DateTime(2026, 1, 1),
);

final kScreenSubscription = Subscription(
  id: 'sub-1',
  userId: 'user-1',
  type: SubscriptionType.free,
  isActive: true,
  autoRenew: false,
  createdAt: DateTime(2026, 1, 1),
  startDate: DateTime(2026, 1, 1),
);

final kScreenVipSubscription = Subscription(
  id: 'sub-2',
  userId: 'user-1',
  type: SubscriptionType.vip,
  isActive: true,
  autoRenew: true,
  createdAt: DateTime(2026, 1, 1),
  startDate: DateTime(2026, 1, 1),
  endDate: DateTime(2027, 1, 1),
);

final kScreenEnergyData = EnergyData(
  id: 'energy-1',
  userId: 'user-1',
  applianceId: 'app-1',
  date: DateTime(2026, 1, 1),
  kwh: 12.5,
  week: 1,
  month: 1,
  year: 2026,
  createdAt: DateTime(2026, 1, 1),
);

final kScreenSyncLog = SyncLog(
  id: 'sync-1',
  boxId: 'box-1',
  userId: 'user-1',
  status: SyncStatus.success,
  timestamp: DateTime(2026, 1, 1),
);

// ─── Fake AuthRepository ─────────────────────────────────────────────────────

class FakeAuthRepository implements AuthRepository {
  User? currentUser;
  bool failLogin;
  bool failOperations;

  FakeAuthRepository({this.currentUser, this.failLogin = false, this.failOperations = false});

  @override
  Future<Either<Failure, User?>> getCurrentUser() async => Right(currentUser);

  @override
  Future<Either<Failure, User>> login(String email, String password) async {
    if (failLogin) return Left(const ServerFailure('Identifiants invalides'));
    return Right(currentUser ?? kScreenUser);
  }

  @override
  Future<Either<Failure, User>> register(String email, String password) async {
    if (failLogin) return Left(const ServerFailure('Inscription échouée'));
    return Right(currentUser ?? kScreenUser);
  }

  @override
  Future<Either<Failure, void>> logout() async => const Right(null);

  @override
  Future<Either<Failure, String>> refreshToken() async => const Right('token');

  @override
  Future<Either<Failure, void>> resetPassword(String email) async {
    if (failOperations) return Left(const ServerFailure('Erreur'));
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> confirmPasswordReset(
      String email, String token, String newPassword) async {
    if (failOperations) return Left(const ServerFailure('Erreur'));
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> changePassword(
      String currentPassword, String newPassword) async {
    if (failOperations) return Left(const ServerFailure('Mot de passe incorrect'));
    return const Right(null);
  }
}

// ─── Fake BoxRepository ──────────────────────────────────────────────────────

class FakeBoxRepository implements BoxRepository {
  List<Box> boxes;
  bool failOperations;

  FakeBoxRepository({List<Box>? boxes, this.failOperations = false})
      : boxes = boxes ?? [kScreenBox];

  @override
  Future<Either<Failure, Box>> addBox(String name, String? location) async {
    if (failOperations) return Left(const ServerFailure('Erreur ajout'));
    return Right(kScreenBox);
  }

  @override
  Future<Either<Failure, void>> removeBox(String boxId) async {
    if (failOperations) return Left(const ServerFailure('Erreur suppression'));
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<Box>>> getUserBoxes() async {
    if (failOperations) return Left(const ServerFailure('Erreur chargement'));
    return Right(boxes);
  }

  @override
  Future<Either<Failure, Box>> pairBoxWithUid(
      String boxId, String uidHardware, String signature) async {
    if (failOperations) return Left(const ServerFailure('Erreur appairage'));
    return Right(kScreenBox);
  }

  @override
  Future<Either<Failure, Box>> identifyBox(String uidHardware) async {
    if (failOperations) return Left(const ServerFailure('Boîtier introuvable'));
    return Right(kScreenBox);
  }
}

// ─── Fake ApplianceRepository ────────────────────────────────────────────────

class FakeApplianceRepository implements ApplianceRepository {
  List<Appliance> appliances;
  bool failOperations;

  FakeApplianceRepository({List<Appliance>? appliances, this.failOperations = false})
      : appliances = appliances ?? [kScreenAppliance];

  @override
  Future<Either<Failure, List<Appliance>>> getUserAppliances() async {
    if (failOperations) return Left(const ServerFailure('Erreur chargement'));
    return Right(appliances);
  }

  @override
  Future<Either<Failure, List<Appliance>>> getBoxAppliances(String boxId) async {
    if (failOperations) return Left(const ServerFailure('Erreur chargement'));
    return Right(appliances);
  }

  @override
  Future<Either<Failure, Appliance>> renameAppliance(
      String applianceId, String name) async {
    if (failOperations) return Left(const ServerFailure('Erreur renommage'));
    return Right(kScreenAppliance.copyWith(name: name));
  }

  @override
  Future<Either<Failure, Appliance>> toggleAppliance(
      String applianceId, bool on) async {
    if (failOperations) return Left(const ServerFailure('Erreur bascule'));
    return Right(kScreenAppliance.copyWith(isOn: on));
  }
}

// ─── Fake LicenseRepository ──────────────────────────────────────────────────

class FakeLicenseRepository implements LicenseRepository {
  Subscription? subscription;
  bool failOperations;
  bool featureAllowed;

  FakeLicenseRepository({
    Subscription? subscription,
    this.failOperations = false,
    this.featureAllowed = false,
  }) : subscription = subscription ?? kScreenSubscription;

  @override
  Future<Either<Failure, Subscription>> getUserSubscription() async {
    if (failOperations) return Left(const ServerFailure('Erreur'));
    return Right(subscription!);
  }

  @override
  Future<Either<Failure, Subscription>> getUserSubscriptionForUser(String userId) async {
    if (failOperations) return Left(const ServerFailure('Erreur'));
    return Right(subscription!);
  }

  @override
  Future<Either<Failure, Subscription>> upgradeToVip(String licenseKey) async {
    if (failOperations) return Left(const ServerFailure('Clé invalide'));
    return Right(kScreenVipSubscription);
  }

  @override
  Future<Either<Failure, Subscription>> cancelSubscription() async {
    if (failOperations) return Left(const ServerFailure('Erreur'));
    return Right(subscription!);
  }

  @override
  Future<Either<Failure, bool>> checkLicenseValidity() async => const Right(true);

  @override
  Future<Either<Failure, bool>> isFeatureAllowed(String featureName) async =>
      Right(featureAllowed);

  @override
  Future<Either<Failure, Subscription>> redeemProductKey(String key) async {
    if (failOperations) return Left(const ServerFailure('Clé invalide'));
    return Right(kScreenVipSubscription);
  }
}

// ─── Fake EnergyRepository ───────────────────────────────────────────────────

class FakeEnergyRepository implements EnergyRepository {
  List<EnergyData> history;
  Map<String, double> byAppliance;
  bool failOperations;

  FakeEnergyRepository({
    List<EnergyData>? history,
    Map<String, double>? byAppliance,
    this.failOperations = false,
  })  : history = history ?? [kScreenEnergyData],
        byAppliance = byAppliance ?? {'Réfrigérateur': 12.5};

  @override
  Future<Either<Failure, List<EnergyData>>> getEnergyHistory({
    required String userId,
    String timeFrame = 'Jour',
  }) async {
    if (failOperations) return Left(const ServerFailure('Erreur'));
    return Right(history);
  }

  @override
  Future<Either<Failure, Map<String, double>>> getEnergyByAppliance({
    required String userId,
    String timeFrame = 'Jour',
  }) async {
    if (failOperations) return Left(const ServerFailure('Erreur'));
    return Right(byAppliance);
  }
}

// ─── Fake SyncRepository ─────────────────────────────────────────────────────

class FakeSyncRepository implements SyncRepository {
  bool failOperations;

  FakeSyncRepository({this.failOperations = false});

  @override
  Future<Either<Failure, SyncLog>> requestSync(String boxId) async {
    if (failOperations) return Left(const ServerFailure('Erreur sync'));
    return Right(kScreenSyncLog);
  }

  @override
  Future<Either<Failure, bool>> validateBoxOwnership(String boxId, String userId) async =>
      const Right(true);

  @override
  Future<Either<Failure, bool>> verifyBoxCryptoUid(
          String boxId, String signature, String nonce) async =>
      const Right(true);

  @override
  Future<Either<Failure, SyncLog>> logSyncResult(
      String boxId, String userId, String status, Map<String, dynamic>? data) async {
    if (failOperations) return Left(const ServerFailure('Erreur'));
    return Right(kScreenSyncLog);
  }
}