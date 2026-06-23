import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBoxDataSource {
  final SupabaseClient _client;
  SupabaseBoxDataSource(this._client);

  Future<Map<String, dynamic>> addBox(String name, String? location, String userId) async {
    final response = await _client.from('boxes').insert({
      'name': name, if (location != null) 'location': location,
      'user_id': userId, 'status': 'inactive', 'uid_hardware': '',
    }).select().single();
    return response;
  }

  Future<void> removeBox(String boxId) async {
    await _client.from('boxes').delete().eq('id', boxId);
  }

  Future<List<Map<String, dynamic>>> getUserBoxes(String userId) async {
    final response = await _client.from('boxes')
      .select().eq('user_id', userId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updateBoxStatus(String boxId, String status) async {
    await _client.from('boxes').update({'status': status}).eq('id', boxId);
  }

  Future<Map<String, dynamic>> pairBox(String boxId, String uidHardware, String userId) async {
    final response = await _client.from('boxes').update({
      'uid_hardware': uidHardware, 'status': 'active',
    }).eq('id', boxId).eq('user_id', userId).select().single();
    return response;
  }

  Future<Map<String, dynamic>?> findBoxByUid(String uidHardware) async {
    final response = await _client.from('boxes')
      .select().eq('uid_hardware', uidHardware).maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>> getBoxById(String boxId) async {
    final response = await _client.from('boxes').select().eq('id', boxId).single();
    return response;
  }
}
