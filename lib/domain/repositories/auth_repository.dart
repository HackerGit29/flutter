import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:dartz/dartz.dart';

abstract class AuthRepository {
  Future<Either<Failure, User>> login(String email, String password);
  Future<Either<Failure, User>> register(String email, String password);
  Future<Either<Failure, void>> logout();
  Future<Either<Failure, void>> resetPassword(String email);
  Future<Either<Failure, void>> confirmPasswordReset(
    String email,
    String token,
    String newPassword,
  );
  Future<Either<Failure, User?>> getCurrentUser();
  Future<Either<Failure, String>> refreshToken();
}
