import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSyncDataSource {
  final SupabaseClient _client;
  SupabaseSyncDataSource(this._client);

  Future<Map<String, dynamic>?> getDeviceById(String deviceId) async {
    final response = await _client.from('devices').select().eq('id', deviceId).maybeSingle();
    return response;
  }

  Future<bool> verifyOwnership(String deviceId, String userId) async {
    final device = await getDeviceById(deviceId);
    if (device == null) return false;
    return device['user_id'] == userId;
  }

  Future<void> updateLastSync(String deviceId) async {
    await _client.from('devices').update({
      'last_sync': DateTime.now().toIso8601String(),
    }).eq('id', deviceId);
  }

  Future<Map<String, dynamic>> createSyncLog(Map<String, dynamic> log) async {
    final response = await _client.from('sync_logs').insert(log).select().single();
    return response;
  }
}
