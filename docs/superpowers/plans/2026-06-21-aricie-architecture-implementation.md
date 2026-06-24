# aricie — Architecture Implementation Plan

> **For agentic workers:** Steps use checkbox (`- [ ]`) syntax. Each phase builds on the previous.

**Goal:** Migration from flat structure to Clean Architecture with auth-first, device ownership, VIP licensing, admin panel, and secure sync.

**Architecture:** Couches core/data/domain/presentation avec DI via get_it. Migration module par module sans casser l'existant.

**Tech Stack:** Flutter 3.29.0, Supabase, MQTT, Riverpod, get_it, mocktail (tests)

---

## File Structure (target)

```
lib/
  main.dart
  core/
    constants.dart
    errors/failures.dart
    di/injection_container.dart
    security/
      token_manager.dart
      device_crypto.dart
      rate_limiter.dart
  data/
    datasources/
      supabase_auth_datasource.dart
      supabase_device_datasource.dart
      supabase_license_datasource.dart
      supabase_admin_datasource.dart
      supabase_sync_datasource.dart
      mqtt_datasource.dart
      local_datasource.dart
    repositories/
      auth_repository_impl.dart
      device_repository_impl.dart
      license_repository_impl.dart
      admin_repository_impl.dart
      sync_repository_impl.dart
  domain/
    entities/
      user.dart
      device.dart
      subscription.dart
      license.dart
      sync_log.dart
      admin_action.dart
    repositories/
      auth_repository.dart
      device_repository.dart
      license_repository.dart
      admin_repository.dart
      sync_repository.dart
    usecases/
      auth/
        login_user.dart
        register_user.dart
        logout_user.dart
        get_current_user.dart
      devices/
        add_device.dart
        remove_device.dart
        get_user_devices.dart
        toggle_device.dart
        pair_device_with_uid.dart
      license/
        get_user_subscription.dart
        upgrade_to_vip.dart
        cancel_subscription.dart
        check_license_validity.dart
        is_feature_allowed.dart
      admin/
        get_all_users.dart
        suspend_user.dart
        activate_user.dart
        assign_role.dart
        get_all_devices.dart
        get_sync_logs.dart
        assign_device.dart
        reset_device.dart
      sync/
        request_sync.dart
        validate_device_ownership.dart
        verify_device_crypto_uid.dart
        log_sync_result.dart
  presentation/
    providers/
    screens/
    widgets/
      premium_gate_widget.dart
    theme/
```

---

## Phase 1 — Core & Domain

### Task 1.1: Create `core/constants.dart`

**Files:**
- Create: `lib/core/constants.dart`

- [ ] **Step: Write the file**

```dart
class AppConstants {
  static const String appName = 'aricie';
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String mqttBrokerUrl = String.fromEnvironment(
    'MQTT_BROKER_URL',
    defaultValue: 'mqtt://test.mosquitto.org:1883',
  );
  static const Duration syncTimeout = Duration(seconds: 30);
  static const int syncRateLimitPerMinute = 10;
  static const int adminActionRateLimitPerMinute = 5;
  static const Duration tokenRefreshMargin = Duration(minutes: 5);
}
```

- [ ] **Step: Commit**

```bash
git add lib/core/constants.dart
git commit -m "feat(core): add AppConstants with env-based config"
```

### Task 1.2: Create `core/errors/failures.dart`

**Files:**
- Create: `lib/core/errors/failures.dart`

- [ ] **Step: Write the file**

```dart
import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  final String message;
  const Failure(this.message);
  @override List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Erreur serveur']);
}
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Erreur réseau']);
}
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Erreur cache local']);
}

// Auth
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Erreur d\'authentification']);
}
class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure([super.message = 'Email ou mot de passe incorrect']);
}
class SessionExpiredFailure extends AuthFailure {
  const SessionExpiredFailure([super.message = 'Session expirée, reconnectez-vous']);
}
class AccountSuspendedFailure extends AuthFailure {
  const AccountSuspendedFailure([super.message = 'Compte suspendu. Contactez l\'administrateur.']);
}

// Devices
class DeviceOwnershipFailure extends Failure {
  const DeviceOwnershipFailure([super.message = 'Vous n\'êtes pas le propriétaire de ce boîtier']);
}
class DeviceNotFoundFailure extends Failure {
  const DeviceNotFoundFailure([super.message = 'Boîtier introuvable']);
}
class DeviceAlreadyAssignedFailure extends Failure {
  const DeviceAlreadyAssignedFailure([super.message = 'Ce boîtier est déjà assigné à un utilisateur']);
}
class DeviceNotIdentifiedFailure extends Failure {
  const DeviceNotIdentifiedFailure([super.message = 'Impossible d\'identifier le boîtier']);
}
class DeviceCryptoMismatchFailure extends Failure {
  const DeviceCryptoMismatchFailure([super.message = 'Signature du boîtier invalide']);
}
class DeviceBlockedFailure extends Failure {
  const DeviceBlockedFailure([super.message = 'Ce boîtier est bloqué']);
}

// License
class LicenseExpiredFailure extends Failure {
  const LicenseExpiredFailure([super.message = 'Abonnement expiré']);
}
class NoActiveSubscriptionFailure extends Failure {
  const NoActiveSubscriptionFailure([super.message = 'Aucun abonnement actif']);
}
class AlreadyHasActiveSubscriptionFailure extends Failure {
  const AlreadyHasActiveSubscriptionFailure([super.message = 'Vous avez déjà un abonnement actif']);
}
class FeatureNotAllowedFailure extends Failure {
  const FeatureNotAllowedFailure([super.message = 'Cette fonctionnalité nécessite un abonnement VIP']);
}

// Admin
class AdminPermissionFailure extends Failure {
  const AdminPermissionFailure([super.message = 'Accès administrateur requis']);
}
class CannotModifySelfFailure extends Failure {
  const CannotModifySelfFailure([super.message = 'Vous ne pouvez pas modifier votre propre compte']);
}

// Sync
class SyncUnauthorizedFailure extends Failure {
  const SyncUnauthorizedFailure([super.message = 'Synchronisation non autorisée']);
}
class SyncRateLimitFailure extends Failure {
  const SyncRateLimitFailure([super.message = 'Trop de tentatives de synchronisation']);
}
class SyncInProgressFailure extends Failure {
  const SyncInProgressFailure([super.message = 'Synchronisation déjà en cours']);
}
```

- [ ] **Step: Commit**

```bash
git add lib/core/errors/failures.dart
git commit -m "feat(core): add sealed Failure hierarchy with all domain errors"
```

### Task 1.3: Create Domain Entities

**Files:**
- Create: `lib/domain/entities/user.dart`
- Create: `lib/domain/entities/device.dart`
- Create: `lib/domain/entities/subscription.dart`
- Create: `lib/domain/entities/license.dart`
- Create: `lib/domain/entities/sync_log.dart`
- Create: `lib/domain/entities/admin_action.dart`

- [ ] **Step: Write `user.dart`**

```dart
enum Role { admin, user, vip }
enum UserStatus { active, suspended }

class User {
  final String id;
  final String email;
  final Role role;
  final UserStatus status;
  final DateTime createdAt;
  final String? subscriptionId;

  const User({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    required this.createdAt,
    this.subscriptionId,
  });

  bool get isAdmin => role == Role.admin;
  bool get isVip => role == Role.vip;
  bool get isSuspended => status == UserStatus.suspended;

  User copyWith({Role? role, UserStatus? status, String? subscriptionId}) {
    return User(
      id: id, email: email,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt,
      subscriptionId: subscriptionId ?? this.subscriptionId,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    email: json['email'] as String,
    role: Role.values.firstWhere((r) => r.name == json['role'] ?? 'user'),
    status: UserStatus.values.firstWhere((s) => s.name == json['status'] ?? 'active'),
    createdAt: DateTime.parse(json['created_at'] as String),
    subscriptionId: json['subscription_id'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'email': email, 'role': role.name,
    'status': status.name, 'created_at': createdAt.toIso8601String(),
    if (subscriptionId != null) 'subscription_id': subscriptionId,
  };
}
```

- [ ] **Step: Write `device.dart`**

```dart
enum DeviceStatus { active, inactive, blocked }

class Device {
  final String id;
  final String uidHardware;
  final String name;
  final String userId;
  final DeviceStatus status;
  final String? publicKey;
  final DateTime? lastSync;
  final String? firmwareVersion;
  final DateTime createdAt;

  const Device({
    required this.id,
    required this.uidHardware,
    required this.name,
    required this.userId,
    required this.status,
    this.publicKey,
    this.lastSync,
    this.firmwareVersion,
    required this.createdAt,
  });

  bool get isOwnedBy => identical(userId, userId); // checked against current user at use-case level
  bool get isActive => status == DeviceStatus.active;
  bool get isBlocked => status == DeviceStatus.blocked;

  Device copyWith({String? uidHardware, String? name, DeviceStatus? status, String? publicKey, DateTime? lastSync, String? firmwareVersion}) {
    return Device(
      id: id, uidHardware: uidHardware ?? this.uidHardware, name: name ?? this.name,
      userId: userId, status: status ?? this.status, publicKey: publicKey ?? this.publicKey,
      lastSync: lastSync ?? this.lastSync, firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      createdAt: createdAt,
    );
  }

  factory Device.fromJson(Map<String, dynamic> json) => Device(
    id: json['id'] as String,
    uidHardware: json['uid_hardware'] as String? ?? '',
    name: json['name'] as String,
    userId: json['user_id'] as String,
    status: DeviceStatus.values.firstWhere(
      (s) => s.name == (json['status'] ?? 'active')),
    publicKey: json['public_key'] as String?,
    lastSync: json['last_sync'] != null ? DateTime.parse(json['last_sync'] as String) : null,
    firmwareVersion: json['firmware_version'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'uid_hardware': uidHardware, 'name': name, 'user_id': userId,
    'status': status.name, 'public_key': publicKey, 'last_sync': lastSync?.toIso8601String(),
    'firmware_version': firmwareVersion, 'created_at': createdAt.toIso8601String(),
  };
}
```

- [ ] **Step: Write `subscription.dart`**

```dart
enum SubscriptionType { free, vip }

class Subscription {
  final String id;
  final String userId;
  final SubscriptionType type;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final bool autoRenew;
  final DateTime createdAt;

  const Subscription({
    required this.id, required this.userId, required this.type,
    required this.startDate, this.endDate,
    required this.isActive, required this.autoRenew, required this.createdAt,
  });

  bool get isVip => type == SubscriptionType.vip;
  bool get isValid => isActive && (endDate == null || DateTime.now().isBefore(endDate));

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    type: SubscriptionType.values.firstWhere((t) => t.name == json['type']),
    startDate: DateTime.parse(json['start_date'] as String),
    endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
    isActive: json['is_active'] as bool? ?? true,
    autoRenew: json['auto_renew'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'user_id': userId, 'type': type.name, 'start_date': startDate.toIso8601String(),
    'end_date': endDate?.toIso8601String(), 'is_active': isActive, 'auto_renew': autoRenew,
    'created_at': createdAt.toIso8601String(),
  };
}
```

- [ ] **Step: Write `license.dart`**

```dart
class License {
  final String id;
  final String subscriptionId;
  final DateTime activationDate;
  final DateTime? expirationDate;
  final String licenseKey;

  const License({
    required this.id, required this.subscriptionId,
    required this.activationDate, this.expirationDate, required this.licenseKey,
  });

  bool get isValid {
    final now = DateTime.now();
    return now.isAfter(activationDate) && (expirationDate == null || now.isBefore(expirationDate));
  }

  factory License.fromJson(Map<String, dynamic> json) => License(
    id: json['id'] as String,
    subscriptionId: json['subscription_id'] as String,
    activationDate: DateTime.parse(json['activation_date'] as String),
    expirationDate: json['expiration_date'] != null ? DateTime.parse(json['expiration_date'] as String) : null,
    licenseKey: json['license_key'] as String,
  );
}
```

- [ ] **Step: Write `sync_log.dart`**

```dart
enum SyncStatus { success, failed, unauthorized, cryptoMismatch, deviceBlocked }

class SyncLog {
  final String id;
  final String deviceId;
  final String userId;
  final SyncStatus status;
  final Map<String, dynamic>? data;
  final String? errorMessage;
  final String? ipAddress;
  final DateTime timestamp;

  const SyncLog({
    required this.id, required this.deviceId, required this.userId,
    required this.status, this.data, this.errorMessage, this.ipAddress, required this.timestamp,
  });

  factory SyncLog.fromJson(Map<String, dynamic> json) => SyncLog(
    id: json['id'] as String,
    deviceId: json['device_id'] as String,
    userId: json['user_id'] as String,
    status: SyncStatus.values.firstWhere((s) => s.name == json['status']),
    data: json['data'] as Map<String, dynamic>?,
    errorMessage: json['error_message'] as String?,
    ipAddress: json['ip_address'] as String?,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
```

- [ ] **Step: Write `admin_action.dart`**

```dart
enum AdminActionType {
  suspendUser, activateUser, assignRole,
  resetDevice, forceSync, overrideOwnership, blockDevice,
  activateLicense, revokeLicense,
}
enum TargetType { user, device, license, subscription }

class AdminAction {
  final String id;
  final String adminId;
  final AdminActionType action;
  final TargetType targetType;
  final String targetId;
  final Map<String, dynamic>? details;
  final DateTime timestamp;

  const AdminAction({
    required this.id, required this.adminId, required this.action,
    required this.targetType, required this.targetId, this.details, required this.timestamp,
  });

  factory AdminAction.fromJson(Map<String, dynamic> json) => AdminAction(
    id: json['id'] as String,
    adminId: json['admin_id'] as String,
    action: AdminActionType.values.firstWhere((a) => a.name == json['action']),
    targetType: TargetType.values.firstWhere((t) => t.name == json['target_type']),
    targetId: json['target_id'] as String,
    details: json['details'] as Map<String, dynamic>?,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
```

- [ ] **Step: Commit entities**

```bash
git add lib/domain/entities/
git commit -m "feat(domain): add all domain entities with JSON serialization"
```

### Task 1.4: Create Repository Interfaces

**Files:**
- Create: `lib/domain/repositories/auth_repository.dart`
- Create: `lib/domain/repositories/device_repository.dart`
- Create: `lib/domain/repositories/license_repository.dart`
- Create: `lib/domain/repositories/admin_repository.dart`
- Create: `lib/domain/repositories/sync_repository.dart`

- [ ] **Step: Write `auth_repository.dart`**

```dart
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:dartz/dartz.dart';

abstract class AuthRepository {
  Future<Either<Failure, User>> login(String email, String password);
  Future<Either<Failure, User>> register(String email, String password);
  Future<Either<Failure, void>> logout();
  Future<Either<Failure, User?>> getCurrentUser();
  Future<Either<Failure, String>> refreshToken();
}
```

- [ ] **Step: Write `device_repository.dart`**

```dart
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/device.dart';
import 'package:dartz/dartz.dart';

abstract class DeviceRepository {
  Future<Either<Failure, Device>> addDevice(String name, String location);
  Future<Either<Failure, void>> removeDevice(String deviceId);
  Future<Either<Failure, List<Device>>> getUserDevices();
  Future<Either<Failure, void>> toggleDevice(String deviceId, bool on);
  Future<Either<Failure, Device>> pairDeviceWithUid(String deviceId, String uidHardware, String signature);
  Future<Either<Failure, Device>> identifyDevice(String uidHardware);
}
```

- [ ] **Step: Write `license_repository.dart`**

```dart
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:aricie/domain/entities/license.dart';
import 'package:dartz/dartz.dart';

abstract class LicenseRepository {
  Future<Either<Failure, Subscription>> getUserSubscription();
  Future<Either<Failure, Subscription>> upgradeToVip(String licenseKey);
  Future<Either<Failure, Subscription>> cancelSubscription();
  Future<Either<Failure, bool>> checkLicenseValidity();
  Future<Either<Failure, bool>> isFeatureAllowed(String featureName);
}
```

- [ ] **Step: Write `admin_repository.dart`**

```dart
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/entities/device.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:aricie/domain/entities/admin_action.dart';
import 'package:dartz/dartz.dart';

abstract class AdminRepository {
  Future<Either<Failure, List<User>>> getAllUsers();
  Future<Either<Failure, User>> suspendUser(String userId);
  Future<Either<Failure, User>> activateUser(String userId);
  Future<Either<Failure, User>> assignRole(String userId, String role);
  Future<Either<Failure, List<Device>>> getAllDevices();
  Future<Either<Failure, List<SyncLog>>> getSyncLogs({String? userId, String? deviceId});
  Future<Either<Failure, Device>> assignDevice(String deviceId, String newUserId);
  Future<Either<Failure, Device>> resetDevice(String deviceId);
}
```

- [ ] **Step: Write `sync_repository.dart`**

```dart
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:dartz/dartz.dart';

abstract class SyncRepository {
  Future<Either<Failure, SyncLog>> requestSync(String deviceId);
  Future<Either<Failure, bool>> validateDeviceOwnership(String deviceId, String userId);
  Future<Either<Failure, bool>> verifyDeviceCryptoUid(String deviceId, String signature, String nonce);
  Future<Either<Failure, SyncLog>> logSyncResult(String deviceId, String userId, String status, Map<String, dynamic>? data);
}
```

- [ ] **Step: Commit repository interfaces**

```bash
git add lib/domain/repositories/
git commit -m "feat(domain): add abstract repository interfaces with Either<Failure, T>"
```

---

## Phase 2 — Data Layer + DI + Security

### Task 2.1: Create DI Container

**Files:**
- Create: `lib/core/di/injection_container.dart`
- Modify: `pubspec.yaml` (add dependencies: `get_it`, `dartz`, `equatable`)

- [ ] **Step: Add deps to pubspec.yaml**

```yaml
dependencies:
  # ... existing deps ...
  get_it: ^8.2.0
  dartz: ^0.10.1
  equatable: ^2.0.7
  flutter_secure_storage: ^9.2.4
```

- [ ] **Step: Write `injection_container.dart`**

```dart
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // Core
  // Will be populated phase by phase
}
```

- [ ] **Step: Commit**

```bash
git add lib/core/di/injection_container.dart pubspec.yaml
git commit -m "feat(core): add get_it DI container, dartz, equatable"
```

### Task 2.2: Create Supabase Datasources

**Files:**
- Create: `lib/data/datasources/supabase_auth_datasource.dart`
- Create: `lib/data/datasources/supabase_device_datasource.dart`
- Create: `lib/data/datasources/supabase_license_datasource.dart`
- Create: `lib/data/datasources/supabase_admin_datasource.dart`
- Create: `lib/data/datasources/supabase_sync_datasource.dart`

- [ ] **Step: Write `supabase_auth_datasource.dart`**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthDataSource {
  final SupabaseClient _client;

  SupabaseAuthDataSource(this._client);

  Future<Map<String, dynamic>> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(email: email, password: password);
    if (response.user == null) throw Exception('Authentication failed');
    final userData = await _client.from('users').select().eq('id', response.user!.id).single();
    return userData as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> signUp(String email, String password) async {
    final response = await _client.auth.signUp(email: email, password: password);
    if (response.user == null) throw Exception('Registration failed');
    final userData = await _client.from('users').select().eq('id', response.user!.id).single();
    return userData as Map<String, dynamic>;
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final data = await _client.from('users').select().eq('id', user.id).single();
    return data as Map<String, dynamic>?;
  }

  Future<String> refreshToken() async {
    final session = _client.auth.currentSession;
    if (session == null) throw Exception('No session');
    final refreshed = await _client.auth.setSession(session.accessToken);
    return refreshed.session!.accessToken;
  }
}
```

- [ ] **Step: Write `supabase_device_datasource.dart`**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDeviceDataSource {
  final SupabaseClient _client;
  SupabaseDeviceDataSource(this._client);

  Future<Map<String, dynamic>> addDevice(String name, String location, String userId) async {
    final response = await _client.from('devices').insert({
      'name': name, 'location': location, 'user_id': userId,
      'status': 'inactive', 'uid_hardware': '',
    }).select().single();
    return response as Map<String, dynamic>;
  }

  Future<void> removeDevice(String deviceId) async {
    await _client.from('devices').delete().eq('id', deviceId);
  }

  Future<List<Map<String, dynamic>>> getUserDevices(String userId) async {
    final response = await _client.from('devices')
      .select().eq('user_id', userId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updateDeviceStatus(String deviceId, String status) async {
    await _client.from('devices').update({'status': status}).eq('id', deviceId);
  }

  Future<Map<String, dynamic>> pairDevice(String deviceId, String uidHardware, String userId) async {
    final response = await _client.from('devices').update({
      'uid_hardware': uidHardware, 'status': 'active',
    }).eq('id', deviceId).eq('user_id', userId).select().single();
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> findDeviceByUid(String uidHardware) async {
    final response = await _client.from('devices')
      .select().eq('uid_hardware', uidHardware).maybeSingle();
    return response as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>> getDeviceById(String deviceId) async {
    final response = await _client.from('devices').select().eq('id', deviceId).single();
    return response as Map<String, dynamic>;
  }
}
```

- [ ] **Step: Write remaining datasources and commit**

```bash
git add lib/data/datasources/
git commit -m "feat(data): add Supabase datasources for auth, devices, license, admin, sync"
```

### Task 2.3: Create Repository Implementations

**Files:**
- Create: `lib/data/repositories/auth_repository_impl.dart`
- Create: `lib/data/repositories/device_repository_impl.dart`
- Create: `lib/data/repositories/license_repository_impl.dart`
- Create: `lib/data/repositories/admin_repository_impl.dart`
- Create: `lib/data/repositories/sync_repository_impl.dart`

- [ ] **Step: Write `auth_repository_impl.dart`**

```dart
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/data/datasources/supabase_auth_datasource.dart';
import 'package:aricie/data/datasources/local_datasource.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseAuthDataSource _remote;
  final LocalDataSource _local;

  AuthRepositoryImpl(this._remote, this._local);

  @override
  Future<Either<Failure, User>> login(String email, String password) async {
    try {
      final data = await _remote.signIn(email, password);
      final user = User.fromJson(data);
      if (user.isSuspended) return Left(AccountSuspendedFailure());
      await _local.cacheSession(user.id, user.email);
      return Right(user);
    } on AccountSuspendedFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(InvalidCredentialsFailure());
    }
  }

  @override
  Future<Either<Failure, User>> register(String email, String password) async {
    try {
      final data = await _remote.signUp(email, password);
      return Right(User.fromJson(data));
    } catch (e) {
      return Left(AuthFailure('Inscription échouée: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _remote.signOut();
      await _local.clearSession();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      final cachedId = await _local.getCachedUserId();
      if (cachedId == null) return const Right(null);
      final data = await _remote.getCurrentUser();
      if (data == null) return const Right(null);
      return Right(User.fromJson(data));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, String>> refreshToken() async {
    try {
      final token = await _remote.refreshToken();
      return Right(token);
    } catch (e) {
      return Left(SessionExpiredFailure());
    }
  }
}
```

- [ ] **Step: Write `local_datasource.dart`**

```dart
import 'package:shared_preferences/shared_preferences.dart';

class LocalDataSource {
  static const _sessionKey = 'user_session';
  static const _userIdKey = 'user_id';
  static const _userEmailKey = 'user_email';

  Future<void> cacheSession(String userId, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sessionKey, true);
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_userEmailKey, email);
  }

  Future<String?> getCachedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSession = prefs.getBool(_sessionKey) ?? false;
    return hasSession ? prefs.getString(_userIdKey) : null;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
  }
}
```

- [ ] **Step: Write remaining repository impls and commit**

```bash
git add lib/data/repositories/ lib/data/datasources/local_datasource.dart
git commit -m "feat(data): add repository implementations and local datasource"
```

### Task 2.4: Create Security Module

**Files:**
- Create: `lib/core/security/token_manager.dart`
- Create: `lib/core/security/device_crypto.dart`
- Create: `lib/core/security/rate_limiter.dart`

- [ ] **Step: Write `token_manager.dart`**

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:aricie/core/constants.dart';

class TokenManager {
  final FlutterSecureStorage _storage;
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  TokenManager(this._storage);

  Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: _accessTokenKey, value: access);
    await _storage.write(key: _refreshTokenKey, value: refresh);
  }

  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);
  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<bool> needsRefresh() async {
    final token = await getAccessToken();
    if (token == null) return false;
    // JWT payload decoding to check exp
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = _decodeBase64(parts[1]);
      final exp = payload['exp'] as int?;
      if (exp == null) return true;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiry.subtract(AppConstants.tokenRefreshMargin));
    } catch (_) {
      return true;
    }
  }

  Map<String, dynamic> _decodeBase64(String str) {
    final normalized = str.replaceAll('-', '+').replaceAll('_', '/');
    final padded = normalized.padRight(normalized.length + (4 - normalized.length % 4) % 4, '=');
    final decoded = String.fromCharCodes(List.from(padded.codeUnits));
    return {}; // Placeholder — use utf8.decode + jsonDecode
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
```

- [ ] **Step: Write remaining security files and commit**

```bash
git add lib/core/security/
git commit -m "feat(core): add security module with token management, device crypto, rate limiter"
```

### Task 2.5: Wire DI Container

- [ ] **Step: Update `injection_container.dart` with all registrations**

```dart
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aricie/core/security/token_manager.dart';
import 'package:aricie/data/datasources/local_datasource.dart';
import 'package:aricie/data/datasources/supabase_auth_datasource.dart';
import 'package:aricie/data/datasources/supabase_device_datasource.dart';
import 'package:aricie/data/datasources/supabase_license_datasource.dart';
import 'package:aricie/data/datasources/supabase_admin_datasource.dart';
import 'package:aricie/data/datasources/supabase_sync_datasource.dart';
import 'package:aricie/data/repositories/auth_repository_impl.dart';
import 'package:aricie/data/repositories/device_repository_impl.dart';
import 'package:aricie/data/repositories/license_repository_impl.dart';
import 'package:aricie/data/repositories/admin_repository_impl.dart';
import 'package:aricie/data/repositories/sync_repository_impl.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:aricie/domain/repositories/device_repository.dart';
import 'package:aricie/domain/repositories/license_repository.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:aricie/domain/repositories/sync_repository.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // Core
  final prefs = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => prefs);
  sl.registerLazySingleton(() => const FlutterSecureStorage());
  sl.registerLazySingleton(() => TokenManager(sl()));

  // Data sources
  sl.registerLazySingleton(() => LocalDataSource());
  sl.registerLazySingleton(() => SupabaseAuthDataSource(Supabase.instance.client));
  sl.registerLazySingleton(() => SupabaseDeviceDataSource(Supabase.instance.client));
  sl.registerLazySingleton(() => SupabaseLicenseDataSource(Supabase.instance.client));
  sl.registerLazySingleton(() => SupabaseAdminDataSource(Supabase.instance.client));
  sl.registerLazySingleton(() => SupabaseSyncDataSource(Supabase.instance.client));

  // Repositories
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl(), sl()));
  sl.registerLazySingleton<DeviceRepository>(() => DeviceRepositoryImpl(sl()));
  sl.registerLazySingleton<LicenseRepository>(() => LicenseRepositoryImpl(sl()));
  sl.registerLazySingleton<AdminRepository>(() => AdminRepositoryImpl(sl()));
  sl.registerLazySingleton<SyncRepository>(() => SyncRepositoryImpl(sl()));
}
```

- [ ] **Step: Commit**

```bash
git add lib/core/di/injection_container.dart
git commit -m "feat(core): wire DI container with all datasources and repositories"
```

---

## Phase 3 — Auth Refactoring

### Task 3.1: Create Auth Use-cases

**Files:**
- Create: `lib/domain/usecases/auth/login_user.dart`
- Create: `lib/domain/usecases/auth/register_user.dart`
- Create: `lib/domain/usecases/auth/logout_user.dart`
- Create: `lib/domain/usecases/auth/get_current_user.dart`

- [ ] **Step: Write `login_user.dart`**

```dart
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class LoginUser {
  final AuthRepository _repository;
  LoginUser(this._repository);

  Future<Either<Failure, User>> call(String email, String password) {
    return _repository.login(email, password);
  }
}
```

- [ ] **Step: Write remaining auth use-cases (same pattern) and commit**

```bash
git add lib/domain/usecases/auth/
git commit -m "feat(domain): add auth use-cases (login, register, logout, getCurrentUser)"
```

### Task 3.2: Refactor LoginScreen to use Clean Architecture

- [ ] **Step: Update `lib/screens/auth/login_screen.dart`** — replace direct Supabase calls with `LoginUser` use-case

```dart
// At top: import domain/usecases/auth/login_user.dart
// In _signIn():
//   final loginUser = LoginUser(sl<AuthRepository>());
//   final result = await loginUser(_emailController.text.trim(), _passwordController.text);
//   result.fold(
//     (failure) => show error,
//     (user) => navigate to Home,
//   );
```

- [ ] **Step: Commit**

```bash
git add lib/screens/auth/login_screen.dart
git commit -m "feat(auth): refactor LoginScreen to use LoginUser use-case"
```

---

## Phase 4 — Devices with Ownership

### Task 4.1: Create Device Use-cases

**Files:**
- Create: `lib/domain/usecases/devices/add_device.dart`
- Create: `lib/domain/usecases/devices/remove_device.dart`
- Create: `lib/domain/usecases/devices/get_user_devices.dart`
- Create: `lib/domain/usecases/devices/toggle_device.dart`
- Create: `lib/domain/usecases/devices/pair_device_with_uid.dart`

- [ ] **Step: Write `add_device.dart`** with ownership binding

```dart
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/device.dart';
import 'package:aricie/domain/repositories/device_repository.dart';
import 'package:dartz/dartz.dart';

class AddDevice {
  final DeviceRepository _repository;
  AddDevice(this._repository);

  Future<Either<Failure, Device>> call(String name, String location) {
    return _repository.addDevice(name, location);
  }
}
```

- [ ] **Step: Write `pair_device_with_uid.dart`**

```dart
class PairDeviceWithUid {
  final DeviceRepository _repository;
  PairDeviceWithUid(this._repository);

  Future<Either<Failure, Device>> call(String deviceId, String uidHardware, String signature) {
    return _repository.pairDeviceWithUid(deviceId, uidHardware, signature);
  }
}
```

- [ ] **Step: Write remaining device use-cases and commit**

```bash
git add lib/domain/usecases/devices/
git commit -m "feat(domain): add device use-cases with ownership enforcement"
```

### Task 4.2: Update DeviceScreen with ownership check

- [ ] **Step: Refactor `devices_screen.dart`** to use `GetUserDevices` use-case (filters by current user automatically)

```bash
git add lib/screens/devices/devices_screen.dart
git commit -m "feat(devices): refactor DevicesScreen to use GetUserDevices use-case"
```

---

## Phase 5 — License/Subscription

### Task 5.1: Create License Use-cases

**Files:**
- Create: `lib/domain/usecases/license/get_user_subscription.dart`
- Create: `lib/domain/usecases/license/upgrade_to_vip.dart`
- Create: `lib/domain/usecases/license/cancel_subscription.dart`
- Create: `lib/domain/usecases/license/check_license_validity.dart`
- Create: `lib/domain/usecases/license/is_feature_allowed.dart`

- [ ] **Step: Write `upgrade_to_vip.dart`**

```dart
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:aricie/domain/repositories/license_repository.dart';
import 'package:dartz/dartz.dart';

class UpgradeToVip {
  final LicenseRepository _repository;
  UpgradeToVip(this._repository);

  Future<Either<Failure, Subscription>> call(String licenseKey) {
    return _repository.upgradeToVip(licenseKey);
  }
}
```

- [ ] **Step: Write `is_feature_allowed.dart`**

```dart
class IsFeatureAllowed {
  final LicenseRepository _repository;
  IsFeatureAllowed(this._repository);

  Future<Either<Failure, bool>> call(String featureName) {
    return _repository.isFeatureAllowed(featureName);
  }
}
```

- [ ] **Step: Commit license use-cases**

### Task 5.2: Create Premium Gate Widget

**Files:**
- Create: `lib/presentation/widgets/premium_gate_widget.dart`

- [ ] **Step: Write `premium_gate_widget.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:aricie/domain/usecases/license/is_feature_allowed.dart';
import 'package:aricie/core/di/injection_container.dart';

class PremiumGateWidget extends StatelessWidget {
  final String featureName;
  final Widget premiumChild;
  final Widget? fallback;

  const PremiumGateWidget({
    super.key,
    required this.featureName,
    required this.premiumChild,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: IsFeatureAllowed(sl()).call(featureName).then(
        (either) => either.getOrElse(() => false)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 24, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        if (snapshot.data == true) return premiumChild;
        return fallback ?? _defaultFallback(context);
      },
    );
  }

  Widget _defaultFallback(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.lock_outline, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text('Fonctionnalité premium', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/upgrade'),
            child: const Text('Passer en VIP'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step: Commit**

```bash
git add lib/domain/usecases/license/ lib/presentation/widgets/premium_gate_widget.dart
git commit -m "feat(license): add license use-cases and PremiumGateWidget"
```

---

## Phase 6 — Admin Panel

### Task 6.1: Create Admin Use-cases

**Files:**
- Create: `lib/domain/usecases/admin/get_all_users.dart`
- Create: `lib/domain/usecases/admin/suspend_user.dart`
- Create: `lib/domain/usecases/admin/activate_user.dart`
- Create: `lib/domain/usecases/admin/assign_role.dart`
- Create: `lib/domain/usecases/admin/get_all_devices.dart`
- Create: `lib/domain/usecases/admin/get_sync_logs.dart`
- Create: `lib/domain/usecases/admin/assign_device.dart`
- Create: `lib/domain/usecases/admin/reset_device.dart`

- [ ] **Step: Write `suspend_user.dart`** with RBAC check

```dart
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class SuspendUser {
  final AdminRepository _adminRepo;
  final AuthRepository _authRepo;
  SuspendUser(this._adminRepo, this._authRepo);

  Future<Either<Failure, User>> call(String targetUserId) async {
    final currentUser = await _authRepo.getCurrentUser();
    final user = currentUser.getOrElse(() => null);
    if (user == null || !user.isAdmin) return Left(AdminPermissionFailure());
    if (user.id == targetUserId) return Left(CannotModifySelfFailure());
    return _adminRepo.suspendUser(targetUserId);
  }
}
```

- [ ] **Step: Commit admin use-cases**

```bash
git add lib/domain/usecases/admin/
git commit -m "feat(admin): add admin use-cases with RBAC checks"
```

---

## Phase 7 — Sync

### Task 7.1: Create Sync Use-cases

**Files:**
- Create: `lib/domain/usecases/sync/request_sync.dart`
- Create: `lib/domain/usecases/sync/validate_device_ownership.dart`
- Create: `lib/domain/usecases/sync/verify_device_crypto_uid.dart`
- Create: `lib/domain/usecases/sync/log_sync_result.dart`

- [ ] **Step: Write `request_sync.dart`** — full sync flow

```dart
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:aricie/domain/repositories/sync_repository.dart';
import 'package:aricie/domain/repositories/device_repository.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';

class RequestSync {
  final SyncRepository _syncRepo;
  final DeviceRepository _deviceRepo;
  final AuthRepository _authRepo;
  RequestSync(this._syncRepo, this._deviceRepo, this._authRepo);

  Future<Either<Failure, SyncLog>> call(String deviceId) async {
    // 1. Auth check
    final currentUser = await _authRepo.getCurrentUser();
    final user = currentUser.getOrElse(() => null);
    if (user == null) return Left(SessionExpiredFailure());

    // 2. Ownership check
    final ownership = await _syncRepo.validateDeviceOwnership(deviceId, user.id);
    final isOwner = ownership.getOrElse(() => false);
    if (!isOwner) {
      await _syncRepo.logSyncResult(deviceId, user.id, 'unauthorized', null);
      return Left(SyncUnauthorizedFailure());
    }

    // 3. Device blocked check
    final deviceResult = await _deviceRepo.getUserDevices();
    final devices = deviceResult.getOrElse(() => []);
    final device = devices.where((d) => d.id == deviceId).firstOrNull;
    if (device == null) return Left(DeviceNotFoundFailure());
    if (device.isBlocked) return Left(DeviceBlockedFailure());

    // 4. Request sync
    return _syncRepo.requestSync(deviceId);
  }
}
```

- [ ] **Step: Commit sync use-cases**

```bash
git add lib/domain/usecases/sync/
git commit -m "feat(sync): add sync use-cases with full auth-ownership-crypto flow"
```

---

## Phase 8 — Tests

### Task 8.1: Unit tests for entities

- [ ] **Step: Write `test/domain/entities/user_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/domain/entities/user.dart';

void main() {
  group('User', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': '123', 'email': 'test@test.com',
        'role': 'admin', 'status': 'active',
        'created_at': '2026-01-01T00:00:00.000Z',
      };
      final user = User.fromJson(json);
      expect(user.role, Role.admin);
      expect(user.isAdmin, true);
      expect(user.isSuspended, false);
    });

    test('isSuspended returns true for suspended users', () {
      final user = User(
        id: '1', email: 'a@b.com', role: Role.user,
        status: UserStatus.suspended, createdAt: DateTime.now(),
      );
      expect(user.isSuspended, true);
    });
  });
}
```

- [ ] **Step: Run tests**

Run: `flutter test test/domain/entities/user_test.dart -v`
Expected: PASS

- [ ] **Step: Write use-case tests with mocktail and commit**

```bash
git add test/domain/entities/user_test.dart
git commit -m "test(domain): add User entity unit tests"
```

---

## Summary

| Phase | Tasks | Files |
|---|---|---|
| **P1** Core & Domain | 4 tasks | ~15 files (entities, repos, failures) |
| **P2** Data & DI | 5 tasks | ~12 files (datasources, impls, security) |
| **P3** Auth | 2 tasks | ~5 files (use-cases, screen refactor) |
| **P4** Devices | 2 tasks | ~6 files (use-cases, screen refactor) |
| **P5** License | 2 tasks | ~7 files (use-cases, widget) |
| **P6** Admin | 1 task | ~8 files (use-cases) |
| **P7** Sync | 1 task | ~4 files (use-cases) |
| **P8** Tests | 1 task | ~10 files |
