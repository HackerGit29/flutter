import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:android_intent_plus/android_intent.dart';
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
          'x-app-version': _currentVersion,
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

  /// Downloads the APK and emits real byte-progress in [0..1].
  /// Yields -1 on any error.
  ///
  /// GitHub release assets redirect via 302 → signed S3 URL.
  /// We use [http.get] (which follows redirects automatically) instead of
  /// [http.Client.send] which does NOT follow redirects on all platforms.
  Stream<double> downloadApk(String url) async* {
    try {
      dev.log('[UpdateService] Starting download: $url', name: 'UpdateService');

      // http.get() follows redirects automatically (GitHub → S3 signed URL).
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(minutes: 10),
      );

      dev.log(
        '[UpdateService] HTTP ${response.statusCode} — contentLength: ${response.contentLength}',
        name: 'UpdateService',
      );

      if (response.statusCode != 200) {
        dev.log(
          '[UpdateService] Download failed: HTTP ${response.statusCode}\n${response.body}',
          name: 'UpdateService',
          level: 900,
        );
        yield -1;
        return;
      }

      final total = response.contentLength ?? response.bodyBytes.length;
      final dir = await getExternalStorageDirectory();
      final base = dir?.path ?? Directory.systemTemp.path;
      final file = File('$base/aricie-update.apk');
      await file.writeAsBytes(response.bodyBytes);

      dev.log(
        '[UpdateService] APK saved to ${file.path} ($total bytes)',
        name: 'UpdateService',
      );

      yield 1.0;
    } catch (e, st) {
      dev.log(
        '[UpdateService] Download exception: $e',
        name: 'UpdateService',
        level: 900,
        error: e,
        stackTrace: st,
      );
      yield -1;
    }
  }

  Future<String?> apkDestination() async {
    final dir = await getExternalStorageDirectory();
    return '${dir?.path ?? Directory.systemTemp.path}/aricie-update.apk';
  }

  Future<void> installApk(String filePath) async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;

    // Use FileProvider authority declared in AndroidManifest.xml so the
    // system installer can read the file on Android 7+ / scoped storage.
    // file_provider_paths.xml maps name="external_files" → getExternalStorageDirectory() root,
    // so the APK at .../files/aricie-update.apk becomes the content URI below.
    const authority = 'com.aricie.app.fileprovider';
    final intent = AndroidIntent(
      action: 'android.intent.action.VIEW',
      data: 'content://$authority/external_files/aricie-update.apk',
      type: 'application/vnd.android.package-archive',
      flags: <int>[1 /* FLAG_GRANT_READ_URI_PERMISSION */],
    );
    try {
      await intent.launch();
    } catch (_) {
      // Fallback: try the legacy file:// scheme on very old devices.
      await Process.run('am', [
        'start',
        '-a',
        'android.intent.action.VIEW',
        '-d',
        'file://$filePath',
        '-t',
        'application/vnd.android.package-archive',
      ]);
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
