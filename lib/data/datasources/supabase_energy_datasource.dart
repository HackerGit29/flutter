import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseEnergyDataSource {
  final SupabaseClient _client;

  SupabaseEnergyDataSource(this._client);

  DateTime _startDateForTimeFrame(String timeFrame) {
    final now = DateTime.now();
    switch (timeFrame) {
      case 'Jour':
        return DateTime(now.year, now.month, now.day);
      case 'Semaine':
        return now.subtract(const Duration(days: 6));
      case 'Mois':
        return DateTime(now.year, now.month, 1);
      case 'Année':
        return DateTime(now.year, 1, 1);
      default:
        return DateTime(now.year, now.month, now.day);
    }
  }

  int _limitForTimeFrame(String timeFrame) {
    switch (timeFrame) {
      case 'Jour': return 1;
      case 'Semaine': return 7;
      case 'Mois': return 31;
      case 'Année': return 366;
      default: return 30;
    }
  }

  Future<List<Map<String, dynamic>>> getEnergyHistory({
    required String userId,
    String timeFrame = 'Jour',
  }) async {
    final startDate = _startDateForTimeFrame(timeFrame);
    final limit = _limitForTimeFrame(timeFrame);

    final response = await _client
        .from('energy_data')
        .select()
        .eq('user_id', userId)
        .gte('date', startDate.toIso8601String().split('T')[0])
        .order('date', ascending: false)
        .limit(limit);

    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getEnergyByAppliance({
    required String userId,
    String timeFrame = 'Jour',
  }) async {
    final startDate = _startDateForTimeFrame(timeFrame);

    final response = await _client
        .from('energy_data')
        .select('appliance_id, kwh')
        .eq('user_id', userId)
        .gte('date', startDate.toIso8601String().split('T')[0]);

    return (response as List).cast<Map<String, dynamic>>();
  }
}
