import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:aricie/domain/usecases/auth/confirm_password_reset.dart';
import 'package:dartz/dartz.dart';

class MockAuthRepository implements AuthRepository {
  @override
  Future<Either<Failure, void>> confirmPasswordReset(
    String email,
    String token,
    String newPassword,
  ) async {
    if (token == '000000') {
      return Left<Failure, void>(const AuthFailure('Code invalide ou expiré'));
    }
    if (newPassword.length < 6) {
      return Left<Failure, void>(
        const AuthFailure('Mise à jour du mot de passe échouée'),
      );
    }
    return const Right<Failure, void>(null);
  }

  @override
  Future<Either<Failure, void>> resetPassword(String email) async {
    return const Right<Failure, void>(null);
  }

  @override
  Future<Either<Failure, void>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    return const Right<Failure, void>(null);
  }

  @override
  Future<Either<Failure, User>> login(String email, String password) async {
    return Left<Failure, User>(const AuthFailure('Not implemented'));
  }

  @override
  Future<Either<Failure, User>> register(String email, String password) async {
    return Left<Failure, User>(const AuthFailure('Not implemented'));
  }

  @override
  Future<Either<Failure, void>> logout() async => const Right<Failure, void>(null);

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    return const Right<Failure, User?>(null);
  }

  @override
  Future<Either<Failure, String>> refreshToken() async {
    return Left<Failure, String>(const SessionExpiredFailure());
  }
}

void main() {
  late ConfirmPasswordReset useCase;

  setUp(() {
    useCase = ConfirmPasswordReset(MockAuthRepository());
  });

  test('returns Right(void) for a valid code and password', () async {
    final result = await useCase('user@aricie.app', '123456', 'newPass123');
    expect(result.isRight(), true);
  });

  test('returns Failure for an invalid/expired code', () async {
    final result = await useCase('user@aricie.app', '000000', 'newPass123');
    expect(result.isLeft(), true);
    result.fold(
      (f) => expect(f.message, contains('Code invalide')),
      (_) {},
    );
  });
}
