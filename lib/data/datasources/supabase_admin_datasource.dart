import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAdminDataSource {
  final SupabaseClient _client;
  SupabaseAdminDataSource(this._client);

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final response = await _client.from('users').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> updateUserStatus(String userId, String status) async {
    final response = await _client.from('users')
      .update({'status': status}).eq('id', userId).select().single();
    return response;
  }

  Future<Map<String, dynamic>> updateUserRole(String userId, String role) async {
    final response = await _client.from('users')
      .update({'role': role}).eq('id', userId).select().single();
    return response;
  }

  Future<List<Map<String, dynamic>>> getAllBoxes() async {
    final response = await _client.from('boxes').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getSyncLogs({String? userId, String? boxId}) async {
    var query = _client.from('sync_logs').select();
    if (userId != null) query = query.eq('user_id', userId);
    if (boxId != null) query = query.eq('box_id', boxId);
    final response = await query.order('timestamp', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> assignBoxToUser(String boxId, String newUserId) async {
    final response = await _client.from('boxes')
      .update({'user_id': newUserId}).eq('id', boxId).select().single();
    return response;
  }

  Future<Map<String, dynamic>> resetBox(String boxId) async {
    final response = await _client.from('boxes').update({
      'uid_hardware': '', 'status': 'inactive', 'public_key': null,
    }).eq('id', boxId).select().single();
    return response;
  }

  Future<Map<String, dynamic>> logAdminAction(Map<String, dynamic> action) async {
    final response = await _client.from('admin_actions').insert(action).select().single();
    return response;
  }
}
