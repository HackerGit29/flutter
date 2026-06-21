import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/device.dart';
import 'package:dartz/dartz.dart';

abstract class DeviceRepository {
  Future<Either<Failure, Device>> addDevice(String name, String location);
  Future<Either<Failure, void>> removeDevice(String deviceId);
  Future<Either<Failure, List<Device>>> getUserDevices();
  Future<Either<Failure, void>> toggleDevice(String deviceId, bool on);
  Future<Either<Failure, Device>> pairDeviceWithUid(String deviceId, String uidHardware, String signature);
  Future<Either<Failure, Device>> identifyDevice(String uidHardware);
}
