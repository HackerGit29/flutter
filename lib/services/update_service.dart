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
import 'package:aricie/services/notification_service.dart';

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

  // Version semver pure ex: "1.3.0"
  static String _appVersion = '0.0.0';
  // Build number ex: "1"
  static String _appBuildNumber = '0';

  String get appVersion => _appVersion;
  String get appBuildNumber => _appBuildNumber;
  /// Version complète affichable : "1.3.0+1"
  String get currentVersion => '$_appVersion+$_appBuildNumber';

  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
      _appBuildNumber = info.buildNumber;
      dev.log(
        '[UpdateService] App version: ${info.version}+${info.buildNumber}',
        name: 'UpdateService',
      );
    } catch (e) {
      dev.log('[UpdateService] PackageInfo error: $e', name: 'UpdateService');
    }
  }

  /// Vérifie une mise à jour seulement si le cooldown de 24h est écoulé.
  /// Appeler après authentification confirmée (HomeScreen.initState).
  Future<void> checkForUpdateIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckStr = prefs.getString('last_update_check');
      if (lastCheckStr != null) {
        final lastCheck = DateTime.tryParse(lastCheckStr);
        if (lastCheck != null &&
            DateTime.now().difference(lastCheck) < const Duration(hours: 24)) {
          dev.log(
            '[UpdateService] Skipping check — last check was $lastCheckStr',
            name: 'UpdateService',
          );
          return;
        }
      }
      final info = await checkForUpdate();
      if (info.updateAvailable) {
        await _sendUpdateNotification(info);
      }
    } catch (e) {
      dev.log(
        '[UpdateService] checkForUpdateIfNeeded error: $e',
        name: 'UpdateService',
      );
    }
  }

  /// Vérifie immédiatement une mise à jour (sans cooldown).
  /// Retourne [UpdateInfo] avec les détails de la release.
  Future<UpdateInfo> checkForUpdate() async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      if (token == null) {
        dev.log(
          '[UpdateService] No auth token — skipping update check',
          name: 'UpdateService',
        );
        return UpdateInfo(updateAvailable: false);
      }

      dev.log(
        '[UpdateService] Checking update — local: $_appVersion+$_appBuildNumber',
        name: 'UpdateService',
      );

      final response = await http.get(
        Uri.parse(_edgeFunctionUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'apikey': AppConstants.supabaseAnonKey,
          // Semver pur (sans build) pour la comparaison principale
          'x-app-version': _appVersion,
          // Build number séparé pour départager les versions semver égales
          'x-build-number': _appBuildNumber,
        },
      ).timeout(const Duration(seconds: 15));

      dev.log(
        '[UpdateService] Edge Function HTTP ${response.statusCode}',
        name: 'UpdateService',
      );

      if (response.statusCode != 200) {
        dev.log(
          '[UpdateService] Edge Function error: ${response.body}',
          name: 'UpdateService',
          level: 900,
        );
        return UpdateInfo(updateAvailable: false);
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      dev.log(
        '[UpdateService] Response: updateAvailable=${body['updateAvailable']} '
        'remote=${body['version']}+${body['buildNumber']} '
        'debug=${body['_debug']}',
        name: 'UpdateService',
      );

      final info = UpdateInfo.fromJson(body);
      _updateController?.add(info);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'last_update_check', DateTime.now().toIso8601String());
      if (info.version != null) {
        await prefs.setString('latest_remote_version', info.version!);
      }

      return info;
    } catch (e, st) {
      dev.log(
        '[UpdateService] checkForUpdate exception: $e',
        name: 'UpdateService',
        level: 900,
        error: e,
        stackTrace: st,
      );
      return UpdateInfo(updateAvailable: false);
    }
  }

  /// Envoie une notification locale "Mise à jour disponible".
  Future<void> _sendUpdateNotification(UpdateInfo info) async {
    try {
      await NotificationService().showNotification(
        id: AppConstants.updateNotificationId,
        title: '🆕 Mise à jour disponible',
        body:
            'Aricie v${info.version ?? "?"} est disponible. Appuyez pour mettre à jour.',
        payload: 'update',
      );
      dev.log(
        '[UpdateService] Notification envoyée pour v${info.version}',
        name: 'UpdateService',
      );
    } catch (e) {
      dev.log(
        '[UpdateService] Notification error: $e',
        name: 'UpdateService',
        level: 900,
      );
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
