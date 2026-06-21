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
