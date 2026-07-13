import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/data/datasources/local_datasource.dart';
import 'package:aricie/data/datasources/supabase_auth_datasource.dart';
import 'package:aricie/data/repositories/auth_repository_impl.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:dartz/dartz.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseAuthDataSource extends Mock implements SupabaseAuthDataSource {}
class MockLocalDataSource extends Mock implements LocalDataSource {}

void main() {
  late MockSupabaseAuthDataSource mockRemote;
  late MockLocalDataSource mockLocal;
  late AuthRepositoryImpl repository;

  setUp(() {
    mockRemote = MockSupabaseAuthDataSource();
    mockLocal = MockLocalDataSource();
    repository = AuthRepositoryImpl(mockRemote, mockLocal);
  });

  group('AuthRepositoryImpl', () {
    const email = 'test@example.com';
    const password = 'password123';
    const userId = 'user-123';

    final mockUserJson = {
      'id': userId,
      'email': email,
      'role': 'user',
      'status': 'active',
      'created_at': '2026-01-01T00:00:00.000Z',
    };

    final mockSuspendedUserJson = {
      'id': userId,
      'email': email,
      'role': 'user',
      'status': 'suspended',
      'created_at': '2026-01-01T00:00:00.000Z',
    };

    group('login', () {
      test('should return User and cache session on success', () async {
        when(() => mockRemote.signIn(email, password)).thenAnswer((_) async => mockUserJson);
        when(() => mockLocal.cacheSession(userId, email)).thenAnswer((_) async => {});

        final result = await repository.login(email, password);

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (user) {
          expect(user.id, userId);
          expect(user.email, email);
          expect(user.isSuspended, false);
        });
        verify(() => mockRemote.signIn(email, password)).called(1);
        verify(() => mockLocal.cacheSession(userId, email)).called(1);
      });

      test('should return AccountSuspendedFailure if user is suspended', () async {
        when(() => mockRemote.signIn(email, password)).thenAnswer((_) async => mockSuspendedUserJson);

        final result = await repository.login(email, password);

        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<AccountSuspendedFailure>());
        }, (_) => fail('should fail'));
        verify(() => mockRemote.signIn(email, password)).called(1);
        verifyNever(() => mockLocal.cacheSession(any(), any()));
      });

      test('should return InvalidCredentialsFailure on exception', () async {
        when(() => mockRemote.signIn(email, password)).thenThrow(Exception('wrong creds'));

        final result = await repository.login(email, password);

        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<InvalidCredentialsFailure>());
        }, (_) => fail('should fail'));
      });
    });

    group('register', () {
      test('should return User on success', () async {
        when(() => mockRemote.signUp(email, password)).thenAnswer((_) async => mockUserJson);

        final result = await repository.register(email, password);

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (user) {
          expect(user.id, userId);
        });
      });

      test('should return AuthFailure on exception', () async {
        when(() => mockRemote.signUp(email, password)).thenThrow(Exception('sign up failed'));

        final result = await repository.register(email, password);

        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, contains('Inscription échouée'));
        }, (_) => fail('should fail'));
      });
    });

    group('logout', () {
      test('should clear session and return Right(null) on success', () async {
        when(() => mockRemote.signOut()).thenAnswer((_) async => {});
        when(() => mockLocal.clearSession()).thenAnswer((_) async => {});

        final result = await repository.logout();

        expect(result.isRight(), true);
        verify(() => mockRemote.signOut()).called(1);
        verify(() => mockLocal.clearSession()).called(1);
      });

      test('should return ServerFailure on exception', () async {
        when(() => mockRemote.signOut()).thenThrow(Exception('logout error'));

        final result = await repository.logout();

        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<ServerFailure>());
        }, (_) => fail('should fail'));
      });
    });

    group('resetPassword', () {
      test('should return Right(null) on success', () async {
        when(() => mockRemote.resetPassword(email)).thenAnswer((_) async => {});

        final result = await repository.resetPassword(email);

        expect(result.isRight(), true);
      });

      test('should return AuthFailure on exception', () async {
        when(() => mockRemote.resetPassword(email)).thenThrow(Exception('reset error'));

        final result = await repository.resetPassword(email);

        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, contains('Envoi du lien de réinitialisation échoué'));
        }, (_) => fail('should fail'));
      });
    });

    group('confirmPasswordReset', () {
      const token = '123456';
      const newPassword = 'newPassword123';

      test('should return Right(null) on success', () async {
        when(() => mockRemote.verifyRecoveryOtp(email, token)).thenAnswer((_) async => {});
        when(() => mockRemote.updatePassword(newPassword)).thenAnswer((_) async => {});

        final result = await repository.confirmPasswordReset(email, token, newPassword);

        expect(result.isRight(), true);
      });

      test('should return AuthFailure if verifyRecoveryOtp throws exception', () async {
        when(() => mockRemote.verifyRecoveryOtp(email, token)).thenThrow(Exception('invalid code'));

        final result = await repository.confirmPasswordReset(email, token, newPassword);

        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, contains('Code invalide ou expiré'));
        }, (_) => fail('should fail'));
      });

      test('should return AuthFailure if updatePassword throws exception after otp success', () async {
        when(() => mockRemote.verifyRecoveryOtp(email, token)).thenAnswer((_) async => {});
        when(() => mockRemote.updatePassword(newPassword)).thenThrow(Exception('weak password'));

        final result = await repository.confirmPasswordReset(email, token, newPassword);

        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, contains('Mise à jour du mot de passe échouée'));
        }, (_) => fail('should fail'));
      });
    });

    group('changePassword', () {
      const currentPassword = 'currentPassword123';
      const newPassword = 'newPassword123';

      test('should return Right(null) on success', () async {
        when(() => mockRemote.verifyCurrentPassword(currentPassword)).thenAnswer((_) async => {});
        when(() => mockRemote.updatePassword(newPassword)).thenAnswer((_) async => {});

        final result = await repository.changePassword(currentPassword, newPassword);

        expect(result.isRight(), true);
      });

      test('should return InvalidCredentialsFailure if current password validation fails', () async {
        when(() => mockRemote.verifyCurrentPassword(currentPassword)).thenThrow(Exception('wrong password'));

        final result = await repository.changePassword(currentPassword, newPassword);

        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<InvalidCredentialsFailure>());
          expect(failure.message, contains('Mot de passe actuel incorrect'));
        }, (_) => fail('should fail'));
      });

      test('should return AuthFailure if updatePassword throws exception', () async {
        when(() => mockRemote.verifyCurrentPassword(currentPassword)).thenAnswer((_) async => {});
        when(() => mockRemote.updatePassword(newPassword)).thenThrow(Exception('failed'));

        final result = await repository.changePassword(currentPassword, newPassword);

        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, contains('Changement du mot de passe échoué'));
        }, (_) => fail('should fail'));
      });
    });

    group('getCurrentUser', () {
      test('should return User if session is cached and user is logged in remote', () async {
        when(() => mockLocal.getCachedUserId()).thenAnswer((_) async => userId);
        when(() => mockRemote.getCurrentUser()).thenAnswer((_) async => mockUserJson);

        final result = await repository.getCurrentUser();

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (user) {
          expect(user, isNotNull);
          expect(user!.id, userId);
        });
      });

      test('should return null if local cached ID is null', () async {
        when(() => mockLocal.getCachedUserId()).thenAnswer((_) async => null);

        final result = await repository.getCurrentUser();

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (user) {
          expect(user, isNull);
        });
      });

      test('should return null if remote user data is null', () async {
        when(() => mockLocal.getCachedUserId()).thenAnswer((_) async => userId);
        when(() => mockRemote.getCurrentUser()).thenAnswer((_) async => null);

        final result = await repository.getCurrentUser();

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (user) {
          expect(user, isNull);
        });
      });

      test('should return ServerFailure on exception', () async {
        when(() => mockLocal.getCachedUserId()).thenAnswer((_) async => userId);
        when(() => mockRemote.getCurrentUser()).thenThrow(Exception('remote error'));

        final result = await repository.getCurrentUser();

        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<ServerFailure>());
        }, (_) => fail('should fail'));
      });
    });

    group('refreshToken', () {
      const mockToken = 'new-refresh-token';

      test('should return token on success', () async {
        when(() => mockRemote.refreshToken()).thenAnswer((_) async => mockToken);

        final result = await repository.refreshToken();

        expect(result.isRight(), true);
        result.fold((_) => fail('should succeed'), (token) {
          expect(token, mockToken);
        });
      });

      test('should return SessionExpiredFailure on exception', () async {
        when(() => mockRemote.refreshToken()).thenThrow(Exception('expired'));

        final result = await repository.refreshToken();

        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<SessionExpiredFailure>());
        }, (_) => fail('should fail'));
      });
    });
  });
}
