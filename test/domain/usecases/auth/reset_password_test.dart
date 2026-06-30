import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:aricie/domain/usecases/auth/reset_password.dart';
import 'package:dartz/dartz.dart';

class MockAuthRepository implements AuthRepository {
  @override
  Future<Either<Failure, void>> resetPassword(String email) async {
    if (email == 'fail@aricie.app') {
      return Left<Failure, void>(
        const AuthFailure('Envoi du lien de réinitialisation échoué'),
      );
    }
    return const Right<Failure, void>(null);
  }

  @override
  Future<Either<Failure, void>> confirmPasswordReset(
    String email,
    String token,
    String newPassword,
  ) async {
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
  late ResetPassword useCase;

  setUp(() {
    useCase = ResetPassword(MockAuthRepository());
  });

  test('returns Right(void) when the reset email is sent', () async {
    final result = await useCase('user@aricie.app');
    expect(result.isRight(), true);
  });

  test('returns Failure when the provider rejects the request', () async {
    final result = await useCase('fail@aricie.app');
    expect(result.isLeft(), true);
    result.fold(
      (f) => expect(f, isA<AuthFailure>()),
      (_) {},
    );
  });
}
