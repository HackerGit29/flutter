import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import '../../models/device_model.dart';
import '../../models/energy_data_model.dart';
import '../../models/temperature_model.dart';
import '../../models/humidity_model.dart';
import '../../widgets/common_header.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  List<DeviceModel> _devices = [];
  String? _selectedDeviceId;
  String _selectedPeriod = 'daily';
  bool _isLoading = true;
  List<EnergyDataModel> _energyData = [];
  List<TemperatureModel> _tempData = [];
  List<HumidityModel> _humData = [];
  
  // Add new variables for animations
  late PageController _pageController;
  bool _isDetailView = false;
  String _selectedMetric = '';
  String _selectedRoom = 'All Devices';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pageController = PageController();
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }
  
  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);
      
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final devicesResponse = await _supabase
            .from('devices')
            .select()
            .eq('user_id', user.id);
        
        _devices = (devicesResponse as List)
            .map((data) => DeviceModel.fromJson(data))
            .toList();
            
        if (_devices.isNotEmpty) {
          setState(() {
            _selectedDeviceId = _devices.first.id;
          });
          await _loadDeviceData();
        }
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadDeviceData() async {
    if (_selectedDeviceId == null || _selectedDeviceId!.isEmpty) return;
    setState(() => _isLoading = true);
    
    try {
      final now = DateTime.now();
      final startDate = _getStartDate();
      
      // Load energy stats
      final energyStatsResponse = await _supabase
          .from('energy_data')
          .select()
          .eq('device_id', _selectedDeviceId as Object)
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', now.toIso8601String())
          .order('created_at');
          
      // Load temperature data
      final tempResponse = await _supabase
          .from('temp_data')
          .select()
          .eq('device_id', _selectedDeviceId as Object)
          .gte('created_at', startDate.toIso8601String())
          .order('created_at');
          
      // Load humidity data
      final humResponse = await _supabase
          .from('hum_data')
          .select()
          .eq('device_id', _selectedDeviceId as Object)
          .gte('created_at', startDate.toIso8601String())
          .order('created_at');
      
      setState(() {
        _energyData = (energyStatsResponse as List)
            .map((data) => EnergyDataModel.fromJson(data))
            .toList();
        _tempData = (tempResponse as List)
            .map((data) => TemperatureModel.fromJson(data))
            .toList();
        _humData = (humResponse as List)
            .map((data) => HumidityModel.fromJson(data))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading device data: $e');
      setState(() => _isLoading = false);
    }
  }
  
  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'daily':
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
      case 'weekly':
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 28));
      case 'monthly':
        return DateTime(now.year, now.month, 1).subtract(const Duration(days: 365));
      default:
        return now.subtract(const Duration(days: 7));
    }
  }

  void _showMetricDetail(String metric) {
    setState(() {
      _selectedMetric = metric;
      _isDetailView = true;
    });
  }

  void _selectRoom(String room) {
    setState(() {
      _selectedRoom = room;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isDetailView 
              ? _buildDetailView()
              : _buildMainView(),
        ),
      ),
    );
  }

  Widget _buildMainView() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CommonHeader(title: 'Statistiques'),
                const SizedBox(height: 24),
                
                // Quick Stats Cards
                SizedBox(
                  height: 160,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildQuickStatCard(
                        'Motion',
                        '75%',
                        Icons.motion_photos_on,
                        Colors.blue,
                        onTap: () => _showMetricDetail('motion'),
                      ),
                      _buildQuickStatCard(
                        'Energy',
                        _getAverageEnergy(),
                        Icons.bolt,
                        Colors.orange,
                        onTap: () => _showMetricDetail('energy'),
                      ),
                      _buildQuickStatCard(
                        'Temperature',
                        _getAverageTemperature(),
                        Icons.thermostat,
                        Colors.red,
                        onTap: () => _showMetricDetail('temperature'),
                      ),
                      _buildQuickStatCard(
                        'Humidity',
                        _getAverageHumidity(),
                        Icons.water_drop,
                        Colors.blue.shade700,
                        onTap: () => _showMetricDetail('humidity'),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Room Selection
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildRoomChip('All Devices', isSelected: _selectedRoom == 'All Devices'),
                      _buildRoomChip('Living Room', isSelected: _selectedRoom == 'Living Room'),
                      _buildRoomChip('Bedroom', isSelected: _selectedRoom == 'Bedroom'),
                      _buildRoomChip('Kitchen', isSelected: _selectedRoom == 'Kitchen'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Device Stats Grid
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _getFilteredDevices().length,
                    itemBuilder: (context, index) {
                      return _buildDeviceStatCard(_getFilteredDevices()[index]);
                    },
                  ),
                ),
              ],
            ),
          );
  }

  List<DeviceModel> _getFilteredDevices() {
    if (_selectedRoom == 'All Devices') {
      return _devices;
    }
    return _devices.where((device) => device.location == _selectedRoom).toList();
  }

  String _getAverageEnergy() {
    if (_energyData.isEmpty) return '0 kWh';
    final avg = _energyData.map((e) => e.consumption).reduce((a, b) => a + b) / _energyData.length;
    return '${avg.toStringAsFixed(1)} kWh';
  }

  String _getAverageTemperature() {
    if (_tempData.isEmpty) return '0°C';
    final avg = _tempData.map((e) => e.temperature).reduce((a, b) => a + b) / _tempData.length;
    return '${avg.toStringAsFixed(1)}°C';
  }

  String _getAverageHumidity() {
    if (_humData.isEmpty) return '0%';
    final avg = _humData.map((e) => e.humidity).reduce((a, b) => a + b) / _humData.length;
    return '${avg.toStringAsFixed(0)}%';
  }

  Widget _buildQuickStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: 'metric_$title',
        child: Container(
          width: 160,
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 32),
              const Spacer(),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomChip(String label, {bool isSelected = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _selectRoom(label),
        backgroundColor: Colors.transparent,
        selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        side: BorderSide(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.withOpacity(0.3),
        ),
        labelStyle: TextStyle(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }

  Widget _buildDeviceStatCard(DeviceModel device) {
    final isActive = device.id.hashCode % 2 == 0; // Simulate active state
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActive
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getDeviceIcon(device.name),
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
              ),
              Switch(
                value: isActive,
                onChanged: (_) {},
              ),
            ],
          ),
          const Spacer(),
          Text(
            device.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            device.location,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(String deviceName) {
    final name = deviceName.toLowerCase();
    if (name.contains('ventilateur')) return Icons.air;
    if (name.contains('télévision') || name.contains('television') || name.contains('tv'))
      return Icons.tv;
    if (name.contains('frigo') || name.contains('congélateur') || name.contains('congelateur'))
      return Icons.kitchen;
    if (name.contains('lumière') || name.contains('ampoule') || name.contains('lampe'))
      return Icons.lightbulb;
    if (name.contains('chauffage')) return Icons.whatshot;
    if (name.contains('climatiseur') || name.contains('clim'))
      return Icons.ac_unit;
    if (name.contains('lave') || name.contains('machine'))
      return Icons.local_laundry_service;
    if (name.contains('four'))
      return Icons.microwave;
    return Icons.devices_other;
  }

  Widget _buildDetailView() {
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: _getMetricColorValue(_selectedMetric),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _isDetailView = false),
              ),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(_getMetricTitle(_selectedMetric)),
                background: _buildMetricBackground(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetricStats(),
                    const SizedBox(height: 24),
                    _buildLineChart(_selectedMetric == 'temperature' 
                        ? _tempData 
                        : _selectedMetric == 'humidity' 
                            ? _humData 
                            : _energyData),
                    const SizedBox(height: 24),
                    _buildMetricInsights(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMotionStats() {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Activité',
                  '75%',
                  Icons.motion_photos_on,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Durée',
                  '2.5h',
                  Icons.timer,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMotionChart(),
        ],
      );
    }
  
  Widget _buildHumidityStats() {
    if (_humData.isEmpty) return const SizedBox.shrink();
    
    final avgHum = _humData.map((e) => e.humidity).reduce((a, b) => a + b) / _humData.length;
    final minHum = _humData.map((e) => e.humidity).reduce(min);
    final maxHum = _humData.map((e) => e.humidity).reduce(max);
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Moyenne',
                '${avgHum.toStringAsFixed(0)}%',
                Icons.water_drop,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Min/Max',
                '${minHum.toStringAsFixed(0)}% / ${maxHum.toStringAsFixed(0)}%',
                Icons.water,
                Colors.lightBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildLineChart(_humData),
      ],
    );
  }
  
  Widget _buildTemperatureChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SfCartesianChart(
        primaryXAxis: DateTimeAxis(
          majorGridLines: const MajorGridLines(width: 0),
        ),
        primaryYAxis: NumericAxis(
          majorGridLines: const MajorGridLines(width: 0),
          labelFormat: '{value}°C',
        ),
        series: <CartesianSeries>[
          SplineAreaSeries<TemperatureModel, DateTime>(
            dataSource: _tempData,
            xValueMapper: (TemperatureModel data, _) => data.createdAt,
            yValueMapper: (TemperatureModel data, _) => data.temperature,
            gradient: LinearGradient(
              colors: [
                Colors.red.withOpacity(0.3),
                Colors.red.withOpacity(0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMotionChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SfCartesianChart(
        primaryXAxis: DateTimeAxis(
          majorGridLines: const MajorGridLines(width: 0),
        ),
        primaryYAxis: NumericAxis(
          majorGridLines: const MajorGridLines(width: 0),
          labelFormat: '{value}%',
        ),
        series: <CartesianSeries>[
          ColumnSeries<EnergyDataModel, DateTime>(
            dataSource: _energyData,
            xValueMapper: (EnergyDataModel data, _) => data.createdAt,
            yValueMapper: (EnergyDataModel data, _) => data.consumption * 100,
            borderRadius: BorderRadius.circular(8),
            color: Colors.blue.withOpacity(0.6),
          ),
        ],
      ),
    );
  }
  
  Color _getMetricColorValue(String metric) {
    switch (metric) {
      case 'motion':
        return Colors.blue;
      case 'energie':
        return Colors.orange;
      case 'temperature':
        return Colors.red;
      case 'humidité':
        return Colors.blue.shade700;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }
  
  Color _getMetricColor(String metric) {
    return _getMetricColorValue(metric);
  }
  
  String _getMetricTitle(String metric) {
    switch (metric) {
      case 'motion':
        return 'Activité de mouvement';
      case 'energy':
        return 'Consommation d\'énergie';
      case 'temperature':
        return 'Contrôle de température';
      case 'humidity':
        return 'Niveau d\'humidité';
      default:
        return 'Détails';
    }
  }
  
  Widget _buildMetricBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _getMetricColorValue(_selectedMetric).withOpacity(0.8),
            _getMetricColorValue(_selectedMetric).withOpacity(0.2),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -50,
            top: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
        ],
      ),
    );
  }
  

  Widget _buildMetricStats() {
    switch (_selectedMetric) {
      case 'energy':
        return _buildEnergyStats();
      case 'temperature':
        return _buildTemperatureStats();
      case 'motion':
        return _buildMotionStats();
      case 'humidity':
        return _buildHumidityStats();
      default:
        return const SizedBox.shrink();
    }
  }
  Widget _buildEnergyStats() {
    final totalConsumption = _energyData.isEmpty ? 0.0 : 
        _energyData.map((e) => e.consumption).reduce((a, b) => a + b);
    final avgConsumption = _energyData.isEmpty ? 0.0 : totalConsumption / _energyData.length;
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total',
                '${totalConsumption.toStringAsFixed(1)} kWh',
                Icons.power,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Moyenne',
                '${avgConsumption.toStringAsFixed(1)} kWh',
                Icons.show_chart,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildLineChart(_energyData),
      ],
    );
  }
  Widget _buildTemperatureStats() {
    if (_tempData.isEmpty) return const SizedBox.shrink();
    
    final avgTemp = _tempData.map((e) => e.temperature).reduce((a, b) => a + b) / _tempData.length;
    final minTemp = _tempData.map((e) => e.temperature).reduce(min);
    final maxTemp = _tempData.map((e) => e.temperature).reduce(max);
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Moyenne',
                '${avgTemp.toStringAsFixed(1)}°C',
                Icons.thermostat,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Min/Max',
                '${minTemp.toStringAsFixed(1)}°C / ${maxTemp.toStringAsFixed(1)}°C',
                Icons.device_thermostat,
                Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTemperatureChart(),
      ],
    );
  }
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildLineChart(List<dynamic> data) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < data.length) {
                    return Text(
                      DateFormat('HH:mm').format(data[value.toInt()].createdAt),
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _getChartData(data),
              isCurved: true,
              gradient: LinearGradient(
                colors: [
                  _getMetricColor(_selectedMetric).withOpacity(0.8),
                  _getMetricColor(_selectedMetric).withOpacity(0.2),
                ],
              ),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    _getMetricColor(_selectedMetric).withOpacity(0.2),
                    _getMetricColor(_selectedMetric).withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  List<FlSpot> _getChartData(List<dynamic> data) {
    if (data.isEmpty) return [];
    
    double maxValue = 0;
    if (data.first is EnergyDataModel) {
      maxValue = data.map((e) => e.consumption).reduce((a, b) => max(a, b)).toDouble();
    } else if (data.first is TemperatureModel) {
      maxValue = data.map((e) => e.temperature).reduce((a, b) => a > b ? a : b).toDouble();
    } else if (data.first is HumidityModel) {
      maxValue = data.map((e) => e.humidity).reduce((a, b) => a > b ? a : b).toDouble();
    }
    
    return List.generate(data.length, (index) {
      double value = 0;
      if (data.first is EnergyDataModel) {
        value = data[index].consumption.toDouble();
      } else if (data.first is TemperatureModel) {
        value = data[index].temperature.toDouble();
      } else if (data.first is HumidityModel) {
        value = data[index].humidity.toDouble();
      }
      return FlSpot(index.toDouble(), value);
    });
  }
  Widget _buildMetricInsights() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
          Text(
            'Insights',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInsightItem(
            icon: Icons.trending_up,
            title: 'Tendance à la hausse',
            description: 'Augmentation de 15% par rapport à la semaine dernière',
            color: Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildInsightItem(
            icon: Icons.access_time,
            title: 'Pic d\'utilisation',
            description: 'Entre 18h et 22h',
            color: Colors.blue,
          ),
        ],
      ),
    );
  }
  Widget _buildInsightItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}