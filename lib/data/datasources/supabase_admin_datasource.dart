import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAdminDataSource {
  final SupabaseClient _client;
  SupabaseAdminDataSource(this._client);

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final response = await _client.from('users').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> getUserById(String userId) async {
    final response = await _client.from('users').select().eq('id', userId).single();
    return response;
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

  Future<Map<String, dynamic>> overrideBoxOwnership(String boxId, String newUserId) async {
    final response = await _client.from('boxes')
      .update({'user_id': newUserId}).eq('id', boxId).select().single();
    await _client.from('appliances').update({'user_id': newUserId}).eq('box_id', boxId);
    return response;
  }

  Future<Map<String, dynamic>> resetBox(String boxId) async {
    final response = await _client.from('boxes').update({
      'uid_hardware': '', 'status': 'inactive', 'public_key': null,
    }).eq('id', boxId).select().single();
    return response;
  }

  Future<Map<String, dynamic>> forceSync(String boxId) async {
    final box = await _client.from('boxes').select().eq('id', boxId).single();
    final now = DateTime.now().toIso8601String();
    await _client.from('boxes').update({'last_sync': now}).eq('id', boxId);
    final response = await _client.from('sync_logs').insert({
      'box_id': boxId,
      'user_id': box['user_id'],
      'status': 'success',
      'data': {'forced_by_admin': true},
      'timestamp': now,
    }).select().single();
    return response;
  }

  Future<List<Map<String, dynamic>>> getAllSubscriptions() async {
    final response = await _client.from('subscriptions').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> updateSubscription(String subscriptionId, Map<String, dynamic> data) async {
    final response = await _client.from('subscriptions')
      .update(data).eq('id', subscriptionId).select().single();
    return response;
  }

  Future<Map<String, dynamic>> logAdminAction(Map<String, dynamic> action) async {
    final response = await _client.from('admin_actions').insert(action).select().single();
    return response;
  }

  Future<List<Map<String, dynamic>>> getAvailableBoxes() async {
    final response = await _client.from('boxes')
      .select()
      .filter('user_id', 'is', 'null')
      .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> createBox({
    required String uidHardware,
    required String name,
    String? location,
    String? userId,
  }) async {
    final response = await _client.from('boxes').insert({
      'uid_hardware': uidHardware,
      'name': name,
      if (location != null) 'location': location,
      if (userId != null) 'user_id': userId,
      'status': 'active',
    }).select().single();
    return response;
  }

  Future<List<Map<String, dynamic>>> createAppliancesForBox(String boxId, String userId) async {
    final rows = List.generate(3, (i) => {
      'box_id': boxId,
      'user_id': userId,
      'relay_index': i + 1,
      'name': 'Appareil ${i + 1}',
      'is_on': false,
    });
    final response = await _client.from('appliances').insert(rows).select();
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getAdminActions({int limit = 50}) async {
    final response = await _client.from('admin_actions')
      .select()
      .order('timestamp', ascending: false)
      .limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getDeviceCommands({int limit = 50}) async {
    final response = await _client.from('device_commands')
      .select()
      .order('created_at', ascending: false)
      .limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }
}
