import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/data/datasources/supabase_device_datasource.dart';
import 'package:aricie/data/datasources/local_datasource.dart';
import 'package:aricie/domain/entities/device.dart';
import 'package:aricie/domain/repositories/device_repository.dart';
import 'package:dartz/dartz.dart';

class DeviceRepositoryImpl implements DeviceRepository {
  final SupabaseDeviceDataSource _remote;
  final LocalDataSource _local;

  DeviceRepositoryImpl(this._remote, this._local);

  @override
  Future<Either<Failure, Device>> addDevice(String name, String location) async {
    try {
      final userId = await _local.getCachedUserId();
      if (userId == null) return Left(SessionExpiredFailure());
      final data = await _remote.addDevice(name, location, userId);
      return Right(Device.fromJson(data));
    } on SessionExpiredFailure {
      return Left(SessionExpiredFailure());
    } catch (e) {
      return Left(ServerFailure('Erreur lors de l\'ajout du boîtier'));
    }
  }

  @override
  Future<Either<Failure, void>> removeDevice(String deviceId) async {
    try {
      await _remote.removeDevice(deviceId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<Device>>> getUserDevices() async {
    try {
      final userId = await _local.getCachedUserId();
      if (userId == null) return Left(SessionExpiredFailure());
      final data = await _remote.getUserDevices(userId);
      final devices = data.map((json) => Device.fromJson(json)).toList();
      return Right(devices);
    } on SessionExpiredFailure {
      return Left(SessionExpiredFailure());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, void>> toggleDevice(String deviceId, bool on) async {
    try {
      await _remote.updateDeviceStatus(deviceId, on ? 'active' : 'inactive');
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Device>> pairDeviceWithUid(String deviceId, String uidHardware, String signature) async {
    try {
      final userId = await _local.getCachedUserId();
      if (userId == null) return Left(SessionExpiredFailure());

      final existing = await _remote.findDeviceByUid(uidHardware);
      if (existing != null && existing['user_id'] != userId) {
        return Left(DeviceAlreadyAssignedFailure());
      }

      final data = await _remote.pairDevice(deviceId, uidHardware, userId);
      return Right(Device.fromJson(data));
    } on DeviceAlreadyAssignedFailure {
      return Left(DeviceAlreadyAssignedFailure());
    } catch (e) {
      return Left(DeviceNotIdentifiedFailure());
    }
  }

  @override
  Future<Either<Failure, Device>> identifyDevice(String uidHardware) async {
    try {
      final data = await _remote.findDeviceByUid(uidHardware);
      if (data == null) return Left(DeviceNotFoundFailure());
      return Right(Device.fromJson(data));
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
