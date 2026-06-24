import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseEnergyDataSource {
  final SupabaseClient _client;

  SupabaseEnergyDataSource(this._client);

  Future<List<Map<String, dynamic>>> getEnergyHistory({
    required String userId,
    int limit = 30,
  }) async {
    final response = await _client
        .from('energy_data')
        .select()
        .eq('user_id', userId)
        .order('date', ascending: false)
        .limit(limit);

    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getEnergyByAppliance({
    required String userId,
  }) async {
    final response = await _client
        .from('energy_data')
        .select('appliance_id, total_day')
        .eq('user_id', userId)
        .gte('date', DateTime.now().subtract(const Duration(days: 1)).toIso8601String());

    return (response as List).cast<Map<String, dynamic>>();
  }
}
