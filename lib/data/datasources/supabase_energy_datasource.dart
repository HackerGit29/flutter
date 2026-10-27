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

  // Plafond d'appareils par utilisateur, utilisé pour dimensionner la limite
  // de lignes : `energy_data` contient une ligne PAR APPAREIL ET PAR JOUR, donc
  // la limite doit couvrir (nb de jours × nb d'appareils), sinon la série
  // journalière est tronquée (bug : « Semaine » ne renvoyait que 7 lignes).
  static const int _maxAppliancesPerUser = 50;

  int _limitForTimeFrame(String timeFrame) {
    final int days;
    switch (timeFrame) {
      case 'Jour': days = 1; break;
      case 'Semaine': days = 7; break;
      case 'Mois': days = 31; break;
      case 'Année': days = 366; break;
      default: days = 30;
    }
    return days * _maxAppliancesPerUser;
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
