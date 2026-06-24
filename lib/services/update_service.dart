import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aricie/core/constants.dart';

class UpdateInfo {
  final bool updateAvailable;
  final String? version;
  final String? apkUrl;
  final String? releaseNotes;
  final bool forceUpdate;
  final String? releaseDate;

  UpdateInfo({
    required this.updateAvailable,
    this.version,
    this.apkUrl,
    this.releaseNotes,
    this.forceUpdate = false,
    this.releaseDate,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) => UpdateInfo(
    updateAvailable: json['updateAvailable'] ?? false,
    version: json['version'] as String?,
    apkUrl: json['apkUrl'] as String?,
    releaseNotes: json['releaseNotes'] as String?,
    forceUpdate: json['forceUpdate'] ?? false,
    releaseDate: json['releaseDate'] as String?,
  );
}

class UpdateService {
  static final UpdateService instance = UpdateService._();
  UpdateService._();

  final _supabase = Supabase.instance.client;
  final _edgeFunctionUrl =
      '${AppConstants.supabaseUrl}/functions/v1/check-update';

  StreamController<UpdateInfo>? _updateController;

  String get currentVersion => _currentVersion;
  static String _currentVersion = '0.0.0';

  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _currentVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {}
  }

  Future<UpdateInfo> checkForUpdate() async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      if (token == null) {
        return UpdateInfo(updateAvailable: false);
      }

      final response = await http.get(
        Uri.parse(_edgeFunctionUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'apikey': AppConstants.supabaseAnonKey,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return UpdateInfo(updateAvailable: false);
      }

      final info = UpdateInfo.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );

      _updateController?.add(info);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_update_check', DateTime.now().toIso8601String());
      if (info.version != null) {
        await prefs.setString('latest_remote_version', info.version!);
      }

      return info;
    } catch (_) {
      return UpdateInfo(updateAvailable: false);
    }
  }

  Future<String?> downloadApk(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(minutes: 5),
      );
      if (response.statusCode != 200) return null;

      final dir = Directory.systemTemp;
      final file = File('${dir.path}/aricie-update.apk');
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> installApk(String filePath) async {
    if (Platform.isAndroid) {
      await Process.run('open', [filePath]);
    }
  }

  void onUpdate(void Function(UpdateInfo) callback) {
    _updateController ??= StreamController<UpdateInfo>.broadcast();
    _updateController!.stream.listen(callback);
  }

  void dispose() {
    _updateController?.close();
  }
}
