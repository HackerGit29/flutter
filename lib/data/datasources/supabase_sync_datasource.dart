import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSyncDataSource {
  final SupabaseClient _client;
  SupabaseSyncDataSource(this._client);

  Future<Map<String, dynamic>?> getBoxById(String boxId) async {
    final response = await _client.from('boxes').select().eq('id', boxId).maybeSingle();
    return response;
  }

  Future<bool> verifyOwnership(String boxId, String userId) async {
    final box = await getBoxById(boxId);
    if (box == null) return false;
    return box['user_id'] == userId;
  }

  Future<void> updateLastSync(String boxId) async {
    await _client.from('boxes').update({
      'last_sync': DateTime.now().toIso8601String(),
    }).eq('id', boxId);
  }

  Future<Map<String, dynamic>> createSyncLog(Map<String, dynamic> log) async {
    final response = await _client.from('sync_logs').insert(log).select().single();
    return response;
  }
}
