import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/energy_data_model.dart';
import '../models/temperature_model.dart';
import '../models/humidity_model.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  final _supabase = Supabase.instance.client;
  
  // Streams pour les données en temps réel
  final ValueNotifier<double> latestTemperature = ValueNotifier<double>(0.0);
  final ValueNotifier<double> latestHumidity = ValueNotifier<double>(0.0);
  final ValueNotifier<Map<String, dynamic>> energyConsumption = ValueNotifier<Map<String, dynamic>>({});
  
  // Abonnements aux canaux
  RealtimeChannel? _tempChannel;
  RealtimeChannel? _humChannel;
  RealtimeChannel? _energyChannel;
  
  factory SupabaseService() {
    return _instance;
  }
  
  SupabaseService._internal();
  
  void initialize() {
    // Charger les données initiales
    _fetchInitialData();
    
    // S'abonner aux canaux en temps réel
    _subscribeToChannels();
  }
  
  void dispose() {
    _unsubscribeFromChannels();
  }
  
  Future<void> _fetchInitialData() async {
    try {
      // Récupérer la dernière température
      final tempResponse = await _supabase
          .from('temp_data')
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .single();
      
      if (tempResponse != null) {
        latestTemperature.value = tempResponse['temperature'] ?? 0.0;
      }
      
      // Récupérer la dernière humidité
      final humResponse = await _supabase
          .from('hum_data')
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .single();
      
      if (humResponse != null) {
        latestHumidity.value = humResponse['humidity'] ?? 0.0;
      }
      
      // Récupérer les dernières données de consommation
      final energyResponse = await _supabase
          .from('energy_consumption')
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .single();
      
      if (energyResponse != null) {
        energyConsumption.value = energyResponse;
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération des données initiales: $e');
    }
  }
  
  void _subscribeToChannels() {
    // S'abonner au canal de température
    _tempChannel = _supabase
        .channel('public:temp_data')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'temp_data',
          callback: (payload) {
            if (payload.newRecord != null) {
              latestTemperature.value = payload.newRecord?['temperature'] ?? 0.0;
            }
          },
        )
        .subscribe((status, error) {
          debugPrint('Statut de la souscription temp_data: $status');
          if (error != null) {
            debugPrint('Erreur de souscription temp_data: $error');
          }
        });
    
    // S'abonner au canal d'humidité
    _humChannel = _supabase
        .channel('public:hum_data')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'hum_data',
          callback: (payload) {
            if (payload.newRecord != null) {
              latestHumidity.value = payload.newRecord?['humidity'] ?? 0.0;
            }
          },
        )
        .subscribe((status, error) {
          debugPrint('Statut de la souscription hum_data: $status');
          if (error != null) {
            debugPrint('Erreur de souscription hum_data: $error');
          }
        });
    
    // S'abonner au canal de consommation d'énergie
    _energyChannel = _supabase
        .channel('public:energy_consumption')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'energy_consumption',
          callback: (payload) {
            if (payload.newRecord != null) {
              energyConsumption.value = payload.newRecord ?? {};
            }
          },
        )
        .subscribe((status, error) {
          debugPrint('Statut de la souscription energy_consumption: $status');
          if (error != null) {
            debugPrint('Erreur de souscription energy_consumption: $error');
          }
        });
  }
  
  void _unsubscribeFromChannels() {
    _tempChannel?.unsubscribe();
    _humChannel?.unsubscribe();
    _energyChannel?.unsubscribe();
  }
  
  // Méthodes pour récupérer les données historiques
  Future<List<TemperatureModel>> getTemperatureHistory({int days = 7}) async {
    try {
      final response = await _supabase
          .from('temp_data')
          .select()
          .order('created_at', ascending: false)
          .limit(days);
      
      return (response as List)
          .map((json) => TemperatureModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Erreur lors de la récupération de l\'historique de température: $e');
      return [];
    }
  }
  
  Future<List<HumidityModel>> getHumidityHistory({int days = 7}) async {
    try {
      final response = await _supabase
          .from('hum_data')
          .select()
          .order('created_at', ascending: false)
          .limit(days);
      
      return (response as List)
          .map((json) => HumidityModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Erreur lors de la récupération de l\'historique d\'humidité: $e');
      return [];
    }
  }
  
  Future<Map<String, dynamic>> getEnergyConsumption(String timeFrame) async {
    try {
      final response = await _supabase
          .from('energy_consumption')
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .single();
      
      switch (timeFrame) {
        case 'Jour':
          return {'value': response['total_day'] ?? 0.0, 'unit': 'kWh'};
        case 'Semaine':
          return {'value': response['total_week'] ?? 0.0, 'unit': 'kWh'};
        case 'Mois':
          return {'value': response['total_month'] ?? 0.0, 'unit': 'kWh'};
        case 'Année':
          return {'value': response['total_year'] ?? 0.0, 'unit': 'kWh'};
        default:
          return {'value': response['total_day'] ?? 0.0, 'unit': 'kWh'};
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération de la consommation d\'énergie: $e');
      return {'value': 0.0, 'unit': 'kWh'};
    }
  }
  
  Future<List<Map<String, dynamic>>> getEnergyConsumptionHistory(String timeFrame, {int limit = 30}) async {
    try {
      String periodField;
      switch (timeFrame) {
        case 'Jour':
          periodField = 'date';
          break;
        case 'Semaine':
          periodField = 'week';
          break;
        case 'Mois':
          periodField = 'month';
          break;
        case 'Année':
          periodField = 'year';
          break;
        default:
          periodField = 'date';
      }
      
      final response = await _supabase
          .from('energy_consumption')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erreur lors de la récupération de l\'historique de consommation: $e');
      return [];
    }
  }
}