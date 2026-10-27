import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:aricie/domain/usecases/auth/login_user.dart';
import 'package:aricie/domain/usecases/auth/register_user.dart';
import 'package:aricie/domain/usecases/auth/logout_user.dart';
import 'package:aricie/domain/usecases/auth/get_current_user.dart';
import 'package:dartz/dartz.dart';

User _user({String email = 'user@aricie.app', Role role = Role.user}) {
  return User(
    id: 'user-1',
    email: email,
    role: role,
    status: UserStatus.active,
    createdAt: DateTime(2026, 1, 1),
  );
}

class MockAuthRepository implements AuthRepository {
  bool loggedOut = false;
  bool hasSession = true;

  @override
  Future<Either<Failure, User>> login(String email, String password) async {
    if (email == 'suspended@aricie.app') {
      return Left<Failure, User>(const AccountSuspendedFailure());
    }
    if (password != 'good') {
      return Left<Failure, User>(const InvalidCredentialsFailure());
    }
    return Right<Failure, User>(_user(email: email));
  }

  @override
  Future<Either<Failure, User>> register(String email, String password) async {
    if (email == 'taken@aricie.app') {
      return Left<Failure, User>(const AuthFailure('Inscription échouée'));
    }
    return Right<Failure, User>(_user(email: email));
  }

  @override
  Future<Either<Failure, void>> logout() async {
    loggedOut = true;
    return const Right<Failure, void>(null);
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    return Right<Failure, User?>(hasSession ? _user() : null);
  }

  @override
  Future<Either<Failure, void>> resetPassword(String email) async =>
      const Right<Failure, void>(null);

  @override
  Future<Either<Failure, void>> confirmPasswordReset(
    String email,
    String token,
    String newPassword,
  ) async =>
      const Right<Failure, void>(null);

  @override
  Future<Either<Failure, void>> changePassword(
    String currentPassword,
    String newPassword,
  ) async =>
      const Right<Failure, void>(null);

  @override
  Future<Either<Failure, String>> refreshToken() async =>
      Left<Failure, String>(const SessionExpiredFailure());
}

void main() {
  late MockAuthRepository repo;

  setUp(() => repo = MockAuthRepository());

  group('LoginUser', () {
    test('renvoie l\'utilisateur sur identifiants valides', () async {
      final result = await LoginUser(repo).call('user@aricie.app', 'good');
      expect(result.isRight(), true);
      result.fold((_) {}, (u) => expect(u.email, 'user@aricie.app'));
    });

    test('renvoie InvalidCredentialsFailure sur mauvais mot de passe', () async {
      final result = await LoginUser(repo).call('user@aricie.app', 'bad');
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<InvalidCredentialsFailure>()), (_) {});
    });

    test('renvoie AccountSuspendedFailure pour un compte suspendu', () async {
      final result = await LoginUser(repo).call('suspended@aricie.app', 'good');
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<AccountSuspendedFailure>()), (_) {});
    });
  });

  group('RegisterUser', () {
    test('crée le compte sur email libre', () async {
      final result = await RegisterUser(repo).call('new@aricie.app', 'good');
      expect(result.isRight(), true);
    });

    test('renvoie une Failure si l\'email est déjà pris', () async {
      final result = await RegisterUser(repo).call('taken@aricie.app', 'good');
      expect(result.isLeft(), true);
    });
  });

  group('LogoutUser', () {
    test('déconnecte et délègue au repository', () async {
      final result = await LogoutUser(repo).call();
      expect(result.isRight(), true);
      expect(repo.loggedOut, true);
    });
  });

  group('GetCurrentUser', () {
    test('renvoie l\'utilisateur courant si session active', () async {
      final result = await GetCurrentUser(repo).call();
      expect(result.isRight(), true);
      result.fold((_) {}, (u) => expect(u, isNotNull));
    });

    test('renvoie null si aucune session', () async {
      repo.hasSession = false;
      final result = await GetCurrentUser(repo).call();
      result.fold((_) {}, (u) => expect(u, isNull));
    });
  });
}
