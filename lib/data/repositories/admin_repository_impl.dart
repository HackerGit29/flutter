import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/data/datasources/supabase_admin_datasource.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:dartz/dartz.dart';

class AdminRepositoryImpl implements AdminRepository {
  final SupabaseAdminDataSource _remote;

  AdminRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<User>>> getAllUsers() async {
    try {
      final data = await _remote.getAllUsers();
      return Right(data.map((json) => User.fromJson(json)).toList());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, User>> suspendUser(String userId) async {
    try {
      final data = await _remote.updateUserStatus(userId, 'suspended');
      return Right(User.fromJson(data));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, User>> activateUser(String userId) async {
    try {
      final data = await _remote.updateUserStatus(userId, 'active');
      return Right(User.fromJson(data));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, User>> assignRole(String userId, String role) async {
    try {
      final data = await _remote.updateUserRole(userId, role);
      return Right(User.fromJson(data));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<Box>>> getAllBoxes() async {
    try {
      final data = await _remote.getAllBoxes();
      return Right(data.map((json) => Box.fromJson(json)).toList());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<SyncLog>>> getSyncLogs({String? userId, String? boxId}) async {
    try {
      final data = await _remote.getSyncLogs(userId: userId, boxId: boxId);
      return Right(data.map((json) => SyncLog.fromJson(json)).toList());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Box>> assignBox(String boxId, String newUserId) async {
    try {
      final data = await _remote.assignBoxToUser(boxId, newUserId);
      return Right(Box.fromJson(data));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Box>> resetBox(String boxId) async {
    try {
      final data = await _remote.resetBox(boxId);
      return Right(Box.fromJson(data));
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
