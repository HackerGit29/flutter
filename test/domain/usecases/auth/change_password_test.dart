import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:aricie/domain/usecases/auth/change_password.dart';
import 'package:dartz/dartz.dart';

class MockAuthRepository implements AuthRepository {
  @override
  Future<Either<Failure, void>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (currentPassword != 'correct') {
      return Left<Failure, void>(
        const InvalidCredentialsFailure('Mot de passe actuel incorrect'),
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
  Future<Either<Failure, void>> resetPassword(String email) async {
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
  late ChangePassword useCase;

  setUp(() {
    useCase = ChangePassword(MockAuthRepository());
  });

  test('returns Right(void) when the current password is correct', () async {
    final result = await useCase('correct', 'newPass123');
    expect(result.isRight(), true);
  });

  test('returns InvalidCredentialsFailure when current password is wrong', () async {
    final result = await useCase('wrong', 'newPass123');
    expect(result.isLeft(), true);
    result.fold(
      (f) => expect(f, isA<InvalidCredentialsFailure>()),
      (_) {},
    );
  });
}
