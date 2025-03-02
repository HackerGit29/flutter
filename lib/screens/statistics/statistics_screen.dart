import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import '../../models/device_model.dart';
import '../../models/energy_data_model.dart';
import '../../models/temperature_model.dart';
import '../../models/humidity_model.dart';
import '../../widgets/common_header.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/metric_chart.dart';
import '../../widgets/device_card.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final List<String> _timeFrames = ['Jour', 'Semaine', 'Mois', 'Année'];
  String _selectedTimeFrame = 'Jour';
  String _selectedRoom = 'Tous';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CommonHeader(title: 'Statistiques'),
                    const SizedBox(height: 16),
                    _buildTimeFrameSelector(),
                    const SizedBox(height: 24),
                    _buildOverallStats(),
                    const SizedBox(height: 24),
                    _buildRoomSelector(),
                  ],
                ),
              ),
            ),
            _buildDevicesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeFrameSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children:
            _timeFrames.map((frame) {
              final isSelected = frame == _selectedTimeFrame;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(frame),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedTimeFrame = frame);
                  },
                  backgroundColor: Colors.transparent,
                  selectedColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.1),
                  labelStyle: TextStyle(
                    color:
                        isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildOverallStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vue d\'ensemble',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            children: [
              StatCard(
                title: 'Consommation',
                value: '2.4 kWh',
                icon: Icons.bolt,
                color: Colors.orange,
                trend: 15,
                onTap: () => _showMetricDetails('energy'),
              ),
              StatCard(
                title: 'Température',
                value: '22°C',
                icon: Icons.thermostat,
                color: Colors.red,
                trend: -5,
                onTap: () => _showMetricDetails('temperature'),
              ),
              StatCard(
                title: 'Humidité',
                value: '45%',
                icon: Icons.water_drop,
                color: Colors.blue,
                trend: 0,
                onTap: () => _showMetricDetails('humidity'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        MetricChart(
          data: _getChartData(),
          title: 'Consommation journalière',
          color: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildRoomSelector() {
    final rooms = ['Tous', 'Salon', 'Cuisine', 'Chambre', 'Bureau'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pièces',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children:
                rooms.map((room) {
                  final isSelected = room == _selectedRoom;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(room),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedRoom = room);
                      },
                      backgroundColor: Colors.transparent,
                      selectedColor: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      labelStyle: TextStyle(
                        color:
                            isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

 
  // Add these variables at the top of the class
  final _supabase = Supabase.instance.client;
  List<DeviceModel> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }


  List<DeviceModel> _getDevices() {
    // Filter devices based on selected room if needed
    if (_selectedRoom == 'Tous') {
      return _devices;
    } else {
      return _devices.where((device) => device.location == _selectedRoom).toList();
    }
  }

  Future<void> _loadDevices() async {
    try {
      setState(() => _isLoading = true);
      
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('devices')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final devices = (response as List)
          .map((json) => DeviceModel.fromJson(json))
          .toList();

      setState(() => _devices = devices);
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement des appareils: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Update the _buildDevicesList method to handle loading state
  Widget _buildDevicesList() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    final devices = _getDevices();
    
    if (devices.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.devices_other,
                size: 64,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Aucun appareil trouvé',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _selectedRoom == 'Tous' 
                    ? 'Ajoutez des appareils dans les paramètres'
                    : 'Aucun appareil dans cette pièce',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => DeviceCard(
            device: devices[index],
            onTap: () => _showDeviceDetails(devices[index]),
          ),
          childCount: devices.length,
        ),
      ),
    );
  }

  List<FlSpot> _getChartData() {
    // Génération de données de consommation basées sur le timeframe sélectionné
    final now = DateTime.now();
    final data = <EnergyDataModel>[];

    int days;
    switch (_selectedTimeFrame) {
      case 'Jour':
        days = 1;
        break;
      case 'Semaine':
        days = 7;
        break;
      case 'Mois':
        days = 30;
        break;
      case 'Année':
        days = 365;
        break;
      default:
        days = 7;
    }

    // Création de données simulées pour la période sélectionnée
    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: days - i - 1));
      data.add(
        EnergyDataModel(
          status: true, // Adding required status parameter
          userId: '1', // Adding required userId parameter
          id: 'energy_$i',
          deviceId: '1',
          consumption: 2.0 + Random().nextDouble() * 3.0,
          createdAt: date,
        ),
      );
    }

    // Conversion en FlSpot pour le graphique
    return data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.consumption);
    }).toList();
  }

  void _showMetricDetails(String metric) {
    // Navigation vers la page de détails avec les données appropriées
    final data = <dynamic>[];
    String title;
    Color color;

    switch (metric) {
      case 'energy':
        // Génération de données de consommation d'énergie
        final now = DateTime.now();
        for (int i = 0; i < 30; i++) {
          final date = now.subtract(Duration(days: 30 - i - 1));
          data.add(
            EnergyDataModel(
              status: true,
              userId: '1',
              id: 'energy_$i',
              deviceId: '1',
              consumption: 1.5 + Random().nextDouble() * 4.0,
              createdAt: date,
            ),
          );
        }
        title = 'Consommation d\'énergie';
        color = Colors.orange;
        break;

      case 'temperature':
        // Génération de données de température
        final now = DateTime.now();
        for (int i = 0; i < 30; i++) {
          final date = now.subtract(Duration(days: 30 - i - 1));
          data.add(
            TemperatureModel(
              userId: '1',
              id: 'temp_$i',
              deviceId: '3',
              temperature: 18.0 + Random().nextDouble() * 10.0,
              createdAt: date,
            ),
          );
        }
        title = 'Température';
        color = Colors.red;
        break;

      case 'humidity':
        // Génération de données d'humidité
        final now = DateTime.now();
        for (int i = 0; i < 30; i++) {
          final date = now.subtract(Duration(days: 30 - i - 1));
          data.add(
            HumidityModel(
              userId: '1',
              id: 'hum_$i',
              deviceId: '3',
              humidity: 30.0 + Random().nextDouble() * 40.0,
              createdAt: date,
            ),
          );
        }
        title = 'Humidité';
        color = Colors.blue;
        break;

      default:
        title = 'Détails';
        color = Theme.of(context).colorScheme.primary;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              appBar: AppBar(title: Text(title)),
              body: MetricChart(
                data: _getFlSpotFromData(data, metric),
                title: title,
                color: color,
              ),
            ),
      ),
    );
  }

  void _showDeviceDetails(DeviceModel device) {
    // Navigation vers la page de détails de l'appareil
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          // TODO: Implement or import DeviceDetailScreen
          // For now, return a placeholder screen
          return Scaffold(
            appBar: AppBar(title: Text(device.name)),
            body: Center(child: Text('Device details coming soon')),
          );
        },
      ),
    );
  }

  List<FlSpot> _getFlSpotFromData(List data, String metric) {
    if (data.isEmpty) return [];

    return data.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      final item = entry.value;
      double value;

      switch (metric) {
        case 'energy':
          value = (item as EnergyDataModel).consumption;
          break;
        case 'temperature':
          value = (item as TemperatureModel).temperature;
          break;
        case 'humidity':
          value = (item as HumidityModel).humidity;
          break;
        default:
          value = 0.0;
      }

      return FlSpot(index, value);
    }).toList();
  }
}
