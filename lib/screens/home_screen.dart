import 'dart:async';

import 'package:aricie/models/temperature_model.dart';
import 'package:flutter/material.dart';
import 'package:aricie/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'statistics/statistics_screen.dart';
import 'devices/devices_screen.dart';
import 'settings/settings_screen.dart';
import '../models/energy_data_model.dart';
import '../widgets/chatbot_floating_button.dart';
import '../services/mqtt_service.dart'; 


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardTab(),
    const StatisticsScreen(),
    const DevicesScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [_screens[_selectedIndex], const ChatbotFloatingButton()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Statistiques',
          ),
          NavigationDestination(
            icon: Icon(Icons.devices_outlined),
            selectedIcon: Icon(Icons.devices),
            label: 'Appareils',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }
}

// Dashboard Tab - Main home view
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final _supabase = Supabase.instance.client;
  final _supabaseService = SupabaseService();
  final _mqttService = MqttService(); 
  bool _isLoading = true;

  // Energy stats data
  Map<String, dynamic> _dailyStats = {};
  Map<String, dynamic> _weeklyStats = {};
  Map<String, dynamic> _monthlyStats = {};

  // Device consumption data
  List<Map<String, dynamic>> _deviceConsumption = [];

  // Données en temps réel
  double _temperature = 0.0;
  double _humidity = 0.0;

   // Données d'énergie en temps réel depuis MQTT
  double _energyDevice1 = 0.0;
  double _energyDevice2 = 0.0;
  double _energyDevice3 = 0.0;

  // Current date
  final String _currentDate = DateFormat('dd MMMM').format(DateTime.now());



  // Subscriptions
  late StreamSubscription<TemperatureModel> _temperatureSubscription;
  late StreamSubscription<double> _humiditySubscription;
  late StreamSubscription<EnergyDataModel> _energySubscription1;
  late StreamSubscription<EnergyDataModel> _energySubscription2;
  late StreamSubscription<EnergyDataModel> _energySubscription3;

  @override
  void initState() {
    super.initState();
    _supabaseService.initialize(); // Initialiser le service Supabase
    _initMqttService();
    _loadEnergyStats();

    // Écouter les changements de données en temps réel
    _supabaseService.energyConsumption.addListener(_updateConsumption);
  }


  void _initMqttService() async {
    await _mqttService.initialize();
    
    // S'abonner au stream de température
    _temperatureSubscription = _mqttService.temperatureStream.listen((tempModel) {
      setState(() {
        _temperature = tempModel.temperature ?? 0.0;
      });
    });
    
    // S'abonner au stream d'humidité
    _humiditySubscription = _mqttService.humidityStream.listen((value) {
      setState(() {
        _humidity = value;
      });
    });

    // S'abonner aux streams d'énergie pour les 3 appareils
    _energySubscription1 = _mqttService.energyDataStream1.listen((energyModel) {
      setState(() {
        _energyDevice1 = energyModel.totalDay ?? 0.0;
        _updateDeviceConsumptionFromMqtt();
      });
    });

    _energySubscription2 = _mqttService.energyDataStream2.listen((energyModel) {
      setState(() {
        _energyDevice2 = energyModel.totalDay ?? 0.0;
        _updateDeviceConsumptionFromMqtt();
      });
    });

     _energySubscription3 = _mqttService.energyDataStream3.listen((energyModel) {
      setState(() {
        _energyDevice3 = energyModel.totalDay ?? 0.0;
        _updateDeviceConsumptionFromMqtt();
      });
    });
    

  }


  // Nouvelle méthode pour mettre à jour les données d'appareil depuis MQTT
  void _updateDeviceConsumptionFromMqtt() {
    _deviceConsumption = [
      {
        'device_id': '1',
        'consumption': _energyDevice1,
        'devices': {'name': 'Appareil 1'},
      },
      {
        'device_id': '2',
        'consumption': _energyDevice2,
        'devices': {'name': 'Appareil 2'},
      },
      {
        'device_id': '3',
        'consumption': _energyDevice3,
        'devices': {'name': 'Appareil 3'},
      },
    ];
  }

  @override
  void dispose() {
    // Supprimer les écouteurs
    _supabaseService.energyConsumption.removeListener(_updateConsumption);
    _temperatureSubscription.cancel();
    _humiditySubscription.cancel();
    _energySubscription1.cancel();
    _energySubscription2.cancel();
    _energySubscription3.cancel();
    super.dispose();
  }

  void _updateConsumption() {
    setState(() {
      final data = _supabaseService.energyConsumption.value;
      _dailyStats = {'consumption': data['total_day'] ?? 0.0};
      _weeklyStats = {'consumption': data['total_week'] ?? 0.0};
      _monthlyStats = {'consumption': data['total_month'] ?? 0.0};

    });
  }

  Future<void> _loadEnergyStats() async {
    setState(() => _isLoading = true);

    try {
      // Utiliser le service Supabase pour récupérer les données
      final consumptionData = _supabaseService.energyConsumption.value;

      if (consumptionData.isNotEmpty) {
        setState(() {
          _dailyStats = {'consumption': consumptionData['total_day'] ?? 0.0};
          _weeklyStats = {'consumption': consumptionData['total_week'] ?? 0.0};
          _monthlyStats = {
            'consumption': consumptionData['total_month'] ?? 0.0,
          };

          _isLoading = false;
        });
      } else {
        // Fallback à la méthode existante si les données ne sont pas disponibles
        final dailyResponse =
            await _supabase
                .from('energy_consumption')
                .select('total_day')
                .order('total_day', ascending: false)
                .limit(1)
                .single();

        // Get weekly stats
        final weeklyResponse =
            await _supabase
                .from('energy_consumption')
                .select('total_week')
                .order('total_week', ascending: false)
                .limit(1)
                .single();

        // Get monthly stats
        final monthlyResponse =
            await _supabase
                .from('energy_consumption')
                .select('total_month')
                .order('total_month', ascending: false)
                .limit(1)
                .single();

        // Get device consumption
        final deviceResponse = await _supabase
            .from('energy_consumption')
            .select('device_id, consumption, devices(name)')
            .eq('period_type', 'daily')
            .order('consumption', ascending: false)
            .limit(5);

        setState(() {
          _dailyStats = dailyResponse;
          _weeklyStats = weeklyResponse;
          _monthlyStats = monthlyResponse;
          _deviceConsumption = List<Map<String, dynamic>>.from(deviceResponse);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading energy stats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with date and notification
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mon Tableau de Bord',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  _currentDate,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(color: Colors.grey),
                                ),
                              ],
                            ),
                            
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Consumption summary carousel
                      CarouselSlider(
                        options: CarouselOptions(
                          height: 180,
                          viewportFraction: 0.9,
                          enableInfiniteScroll: true,
                          autoPlay: true,
                          autoPlayInterval: const Duration(seconds: 5),
                          autoPlayAnimationDuration: const Duration(
                            milliseconds: 800,
                          ),
                          autoPlayCurve: Curves.fastOutSlowIn,
                          enlargeCenterPage: true,
                        ),
                        items: [
                          _buildTemperatureCard(), 
                          _buildHumidityCard(),   
                          _buildConsumptionCard(
                            'Consommation Journalière',
                            _dailyStats['consumption']?.toStringAsFixed(1) ??
                                '0.0',
                            '+5%',
                            Colors.red,
                            Icons.arrow_upward,
                            Colors.orange.shade100,
                            Colors.orange,
                          ),
                          _buildConsumptionCard(
                            'Consommation Hebdomadaire',
                            _weeklyStats['consumption']?.toStringAsFixed(1) ??
                                '0.0',
                            '-3%',
                            Colors.green,
                            Icons.arrow_downward,
                            Colors.blue.shade100,
                            Colors.blue,
                          ),
                          _buildConsumptionCard(
                            'Consommation Mensuelle',
                            _monthlyStats['consumption']?.toStringAsFixed(1) ??
                                '0.0',
                            '+10%',
                            Colors.red,
                            Icons.arrow_upward,
                            Colors.purple.shade100,
                            Colors.purple,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Section title
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Répartition par Appareil',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => const StatisticsScreen(),
                                    ),
                                  );
                                });
                              },
                              child: const Text('Voir plus'),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Realtime device consumption 
                      GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1.5,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                        itemCount: 3,
                        itemBuilder: (context, index) {
                          // Utiliser directement les données MQTT
                          final deviceNames = ['Appareil 1', 'Appareil 2', 'Appareil 3'];
                          final energyValues = [_energyDevice1, _energyDevice2, _energyDevice3];
                          
                          final deviceName = deviceNames[index];
                          final consumption = energyValues[index].toStringAsFixed(1);

                          return _buildDeviceCard(
                            deviceName,
                            consumption,
                            _getDeviceIcon(deviceName),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // Weekly consumption chart
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tendance Hebdomadaire',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              height: 200,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: _buildWeeklyChart(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Tips section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 26.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Conseils d\'économie',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            _buildTipCard(
                              'Réduisez votre consommation en éteignant les appareils en veille',
                              Icons.lightbulb_outline,
                              Colors.amber.shade100,
                              Colors.amber,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildConsumptionCard(
    String title,
    String value,
    String change,
    Color changeColor,
    IconData changeIcon,
    Color cardColor,
    Color iconColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.electric_bolt, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'kWh',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: changeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(changeIcon, color: changeColor, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      change,
                      style: TextStyle(
                        color: changeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(
    String deviceName,
    String consumption,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
          const Spacer(),
          Text(
            deviceName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '$consumption kWh',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(String deviceName) {
    final name = deviceName.toLowerCase();
    if (name.contains('tv') || name.contains('télé')) {
      return Icons.tv;
    } else if (name.contains('frigo') || name.contains('réfrigérateur')) {
      return Icons.kitchen;
    } else if (name.contains('lumière') || name.contains('lampe')) {
      return Icons.lightbulb;
    } else if (name.contains('clim') || name.contains('climatiseur')) {
      return Icons.ac_unit;
    } else if (name.contains('machine') || name.contains('lave')) {
      return Icons.local_laundry_service;
    } else if (name.contains('four') || name.contains('micro')) {
      return Icons.microwave;
    } else {
      return Icons.devices_other;
    }
  }

  Widget _buildWeeklyChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()} kWh',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
                if (value.toInt() < 0 || value.toInt() >= days.length) {
                  return const Text('');
                }
                return Text(
                  days[value.toInt()],
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                );
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              const FlSpot(0, 3),
              const FlSpot(1, 2),
              const FlSpot(2, 5),
              const FlSpot(3, 3.1),
              const FlSpot(4, 4),
              const FlSpot(5, 3),
              const FlSpot(6, 4),
            ],
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withOpacity(0.5),
              ],
            ),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  Theme.of(context).colorScheme.primary.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(
    String tip,
    IconData icon,
    Color backgroundColor,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  
Widget _buildTemperatureCard() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.blue.shade100,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.thermostat, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              'Température',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
             _temperature.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                '°C',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.update, color: Colors.blue, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Temps réel',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildHumidityCard() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.teal.shade100,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.water_drop, color: Colors.teal),
            const SizedBox(width: 8),
            Text(
              'Humidité',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _humidity.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                '%',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.update, color: Colors.teal, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Temps réel',
                    style: TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
}
