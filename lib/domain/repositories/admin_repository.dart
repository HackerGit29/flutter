import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/entities/device.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:dartz/dartz.dart';

abstract class AdminRepository {
  Future<Either<Failure, List<User>>> getAllUsers();
  Future<Either<Failure, User>> suspendUser(String userId);
  Future<Either<Failure, User>> activateUser(String userId);
  Future<Either<Failure, User>> assignRole(String userId, String role);
  Future<Either<Failure, List<Device>>> getAllDevices();
  Future<Either<Failure, List<SyncLog>>> getSyncLogs({String? userId, String? deviceId});
  Future<Either<Failure, Device>> assignDevice(String deviceId, String newUserId);
  Future<Either<Failure, Device>> resetDevice(String deviceId);
}
