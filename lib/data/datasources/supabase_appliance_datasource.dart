import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseApplianceDataSource {
  final SupabaseClient _client;
  SupabaseApplianceDataSource(this._client);

  Future<List<Map<String, dynamic>>> getUserAppliances(String userId) async {
    final response = await _client.from('appliances')
      .select('*, boxes!inner(uid_hardware)')
      .eq('user_id', userId)
      .order('created_at', ascending: false);

    final list = List<Map<String, dynamic>>.from(response);
    for (final item in list) {
      final boxes = item['boxes'] as Map<String, dynamic>?;
      if (boxes != null) {
        item['box_uid'] = boxes['uid_hardware'];
      }
      item.remove('boxes');
    }
    return list;
  }

  Future<List<Map<String, dynamic>>> getBoxAppliances(String boxId) async {
    final response = await _client.from('appliances')
      .select().eq('box_id', boxId).order('relay_index', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> updateApplianceName(String applianceId, String name) async {
    final response = await _client.from('appliances')
      .update({'name': name}).eq('id', applianceId).select().single();
    return response;
  }

  Future<Map<String, dynamic>> toggleAppliance(String applianceId, bool isOn) async {
    final response = await _client.from('appliances')
      .update({'is_on': isOn}).eq('id', applianceId).select().single();
    return response;
  }

  Future<List<Map<String, dynamic>>> createAppliancesForBox(String boxId, String userId) async {
    final rows = List.generate(3, (i) => {
      'box_id': boxId, 'user_id': userId, 'relay_index': i + 1,
      'name': 'Appareil ${i + 1}', 'is_on': false,
    });
    final response = await _client.from('appliances').insert(rows).select();
    return List<Map<String, dynamic>>.from(response);
  }
}
