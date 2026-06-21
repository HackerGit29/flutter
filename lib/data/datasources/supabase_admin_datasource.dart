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

  Future<List<Map<String, dynamic>>> getAllDevices() async {
    final response = await _client.from('devices').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getSyncLogs({String? userId, String? deviceId}) async {
    var query = _client.from('sync_logs').select();
    if (userId != null) query = query.eq('user_id', userId);
    if (deviceId != null) query = query.eq('device_id', deviceId);
    final response = await query.order('timestamp', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> updateDeviceUser(String deviceId, String newUserId) async {
    final response = await _client.from('devices')
      .update({'user_id': newUserId}).eq('id', deviceId).select().single();
    return response;
  }

  Future<Map<String, dynamic>> resetDevice(String deviceId) async {
    final response = await _client.from('devices').update({
      'uid_hardware': '', 'status': 'inactive', 'public_key': null,
    }).eq('id', deviceId).select().single();
    return response;
  }

  Future<Map<String, dynamic>> logAdminAction(Map<String, dynamic> action) async {
    final response = await _client.from('admin_actions').insert(action).select().single();
    return response;
  }
}
