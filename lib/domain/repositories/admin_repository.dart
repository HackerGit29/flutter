import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:dartz/dartz.dart';

abstract class AdminRepository {
  Future<Either<Failure, List<User>>> getAllUsers();
  Future<Either<Failure, User>> suspendUser(String userId);
  Future<Either<Failure, User>> activateUser(String userId);
  Future<Either<Failure, User>> assignRole(String userId, String role);
  Future<Either<Failure, List<Box>>> getAllBoxes();
  Future<Either<Failure, List<SyncLog>>> getSyncLogs({String? userId, String? boxId});
  Future<Either<Failure, Box>> assignBox(String boxId, String newUserId);
  Future<Either<Failure, Box>> resetBox(String boxId);
}
