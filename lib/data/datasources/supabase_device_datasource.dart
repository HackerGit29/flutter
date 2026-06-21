import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDeviceDataSource {
  final SupabaseClient _client;
  SupabaseDeviceDataSource(this._client);

  Future<Map<String, dynamic>> addDevice(String name, String location, String userId) async {
    final response = await _client.from('devices').insert({
      'name': name, 'location': location, 'user_id': userId,
      'status': 'inactive', 'uid_hardware': '',
    }).select().single();
    return response;
  }

  Future<void> removeDevice(String deviceId) async {
    await _client.from('devices').delete().eq('id', deviceId);
  }

  Future<List<Map<String, dynamic>>> getUserDevices(String userId) async {
    final response = await _client.from('devices')
      .select().eq('user_id', userId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updateDeviceStatus(String deviceId, String status) async {
    await _client.from('devices').update({'status': status}).eq('id', deviceId);
  }

  Future<Map<String, dynamic>> pairDevice(String deviceId, String uidHardware, String userId) async {
    final response = await _client.from('devices').update({
      'uid_hardware': uidHardware, 'status': 'active',
    }).eq('id', deviceId).eq('user_id', userId).select().single();
    return response;
  }

  Future<Map<String, dynamic>?> findDeviceByUid(String uidHardware) async {
    final response = await _client.from('devices')
      .select().eq('uid_hardware', uidHardware).maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>> getDeviceById(String deviceId) async {
    final response = await _client.from('devices').select().eq('id', deviceId).single();
    return response;
  }
}
