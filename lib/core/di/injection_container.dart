import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aricie/core/security/token_manager.dart';
import 'package:aricie/data/datasources/local_datasource.dart';
import 'package:aricie/data/datasources/supabase_auth_datasource.dart';
import 'package:aricie/data/datasources/supabase_box_datasource.dart';
import 'package:aricie/data/datasources/supabase_appliance_datasource.dart';
import 'package:aricie/data/datasources/supabase_license_datasource.dart';
import 'package:aricie/data/datasources/supabase_admin_datasource.dart';
import 'package:aricie/data/datasources/supabase_sync_datasource.dart';
import 'package:aricie/data/datasources/supabase_energy_datasource.dart';
import 'package:aricie/data/repositories/auth_repository_impl.dart';
import 'package:aricie/data/repositories/box_repository_impl.dart';
import 'package:aricie/data/repositories/appliance_repository_impl.dart';
import 'package:aricie/data/repositories/license_repository_impl.dart';
import 'package:aricie/data/repositories/admin_repository_impl.dart';
import 'package:aricie/data/repositories/sync_repository_impl.dart';
import 'package:aricie/data/repositories/energy_repository_impl.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:aricie/domain/repositories/box_repository.dart';
import 'package:aricie/domain/repositories/appliance_repository.dart';
import 'package:aricie/domain/repositories/license_repository.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:aricie/domain/repositories/sync_repository.dart';
import 'package:aricie/domain/repositories/energy_repository.dart';
import 'package:aricie/services/mqtt_service.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  final prefs = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => prefs);
  sl.registerLazySingleton(() => const FlutterSecureStorage());
  sl.registerLazySingleton(() => TokenManager(sl()));

  sl.registerLazySingleton(() => LocalDataSource());
  sl.registerLazySingleton(() => SupabaseAuthDataSource(Supabase.instance.client));
  sl.registerLazySingleton(() => SupabaseBoxDataSource(Supabase.instance.client));
  sl.registerLazySingleton(() => SupabaseApplianceDataSource(Supabase.instance.client));
  sl.registerLazySingleton(() => SupabaseLicenseDataSource(Supabase.instance.client));
  sl.registerLazySingleton(() => SupabaseAdminDataSource(Supabase.instance.client));
  sl.registerLazySingleton(() => SupabaseSyncDataSource(Supabase.instance.client));
  sl.registerLazySingleton(() => SupabaseEnergyDataSource(Supabase.instance.client));

  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl(), sl()));
  sl.registerLazySingleton<BoxRepository>(() => BoxRepositoryImpl(sl(), sl(), sl()));
  sl.registerLazySingleton<ApplianceRepository>(() => ApplianceRepositoryImpl(sl(), sl()));
  sl.registerLazySingleton<LicenseRepository>(() => LicenseRepositoryImpl(sl(), sl()));
  sl.registerLazySingleton<AdminRepository>(() => AdminRepositoryImpl(sl()));
  sl.registerLazySingleton<SyncRepository>(() => SyncRepositoryImpl(sl()));
  sl.registerLazySingleton<EnergyRepository>(() => EnergyRepositoryImpl(sl()));
  sl.registerLazySingleton<MqttService>(() => MqttService());
}
