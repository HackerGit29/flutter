import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/entities/appliance.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:aricie/domain/repositories/appliance_repository.dart';
import 'package:aricie/domain/usecases/auth/register_user.dart';
import 'package:aricie/domain/usecases/auth/logout_user.dart';
import 'package:aricie/domain/usecases/devices/toggle_device.dart';
import 'package:dartz/dartz.dart';

class MockAuthRepository extends AuthRepository {
  @override
  Future<Either<Failure, User>> register(String email, String password) async {
    if (!email.contains('@')) {
      return Left<Failure, User>(AuthFailure('Email invalide'));
    }
    return Right<Failure, User>(User(
      id: 'user-1', email: email, role: Role.user,
      status: UserStatus.active, createdAt: DateTime.now(),
    ));
  }

  @override
  Future<Either<Failure, User>> login(String email, String password) async {
    return Right<Failure, User>(User(
      id: 'user-1', email: email, role: Role.user,
      status: UserStatus.active, createdAt: DateTime.now(),
    ));
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    return Right<Failure, User?>(User(
      id: 'user-1', email: 'test@test.com', role: Role.user,
      status: UserStatus.active, createdAt: DateTime.now(),
    ));
  }

  @override
  Future<Either<Failure, void>> logout() async {
    return const Right<Failure, void>(null);
  }

  @override
  Future<Either<Failure, String>> refreshToken() async {
    return const Right<Failure, String>('new-token');
  }
}

class MockApplianceRepository extends ApplianceRepository {
  @override
  Future<Either<Failure, Appliance>> toggleAppliance(
    String applianceId, bool on,
  ) async {
    return Right<Failure, Appliance>(Appliance(
      id: applianceId, boxId: 'box-1', userId: 'user-1',
      relayIndex: 1, name: 'Heater', createdAt: DateTime.now(),
    ));
  }

  @override
  Future<Either<Failure, List<Appliance>>> getUserAppliances() async {
    return const Right<Failure, List<Appliance>>([]);
  }

  @override
  Future<Either<Failure, List<Appliance>>> getBoxAppliances(String boxId) async {
    return const Right<Failure, List<Appliance>>([]);
  }

  @override
  Future<Either<Failure, Appliance>> renameAppliance(
    String applianceId, String name,
  ) async {
    return Right<Failure, Appliance>(Appliance(
      id: applianceId, boxId: 'box-1', userId: 'user-1',
      relayIndex: 1, name: name, createdAt: DateTime.now(),
    ));
  }
}

void main() {
  group('Domain Logic', () {
    test('RegisterUser returns User for valid email', () async {
      final usecase = RegisterUser(MockAuthRepository());
      final result = await usecase('user@test.com', 'password123');
      expect(result.isRight(), true);
      result.fold((_) {}, (user) {
        expect(user.email, 'user@test.com');
        expect(user.role, Role.user);
      });
    });

    test('RegisterUser returns Failure for invalid email', () async {
      final usecase = RegisterUser(MockAuthRepository());
      final result = await usecase('invalid-email', 'password123');
      expect(result.isLeft(), true);
    });

    test('LogoutUser returns success', () async {
      final usecase = LogoutUser(MockAuthRepository());
      final result = await usecase();
      expect(result.isRight(), true);
    });

    test('ToggleDevice returns success', () async {
      final usecase = ToggleDevice(MockApplianceRepository());
      final result = await usecase('appliance-1', true);
      expect(result.isRight(), true);
    });
  });
}
