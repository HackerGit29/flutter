import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
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
    if (_selectedDeviceId == null || _selectedDeviceId!.isEmpty) return;  // Check for null or empty string
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
  
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CommonHeader(title: 'Statistiques'),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedDeviceId,
                    decoration: const InputDecoration(
                      labelText: 'Appareil',
                      border: OutlineInputBorder(),
                    ),
                    items: _devices.map((device) {
                      return DropdownMenuItem(
                        value: device.id,
                        child: Text(device.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedDeviceId = value);
                      _loadDeviceData();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedPeriod,
                    decoration: const InputDecoration(
                      labelText: 'Période',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'daily', child: Text('Journalier')),
                      DropdownMenuItem(value: 'weekly', child: Text('Hebdomadaire')),
                      DropdownMenuItem(value: 'monthly', child: Text('Mensuel')),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedPeriod = value!);
                      _loadDeviceData();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Consommation'),
                Tab(text: 'Température'),
                Tab(text: 'Humidité'),
              ],
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildEnergyChart(),
                        _buildTemperatureChart(),
                        _buildHumidityChart(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEnergyChart() {
    if (_energyData.isEmpty) {
      return const Center(child: Text('Aucune donnée disponible'));
    }
  
    return SfCartesianChart(
      primaryXAxis: DateTimeAxis(
        dateFormat: DateFormat('dd/MM HH:mm'),
        intervalType: DateTimeIntervalType.auto,
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: 'Consommation (kWh)'),
      ),
      series: <CartesianSeries<EnergyDataModel, DateTime>>[  // Change from ChartSeries to CartesianSeries
        SplineAreaSeries<EnergyDataModel, DateTime>(
          dataSource: _energyData,
          xValueMapper: (data, _) => data.createdAt,
          yValueMapper: (data, _) => data.consumption,
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.3),
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderColor: Theme.of(context).colorScheme.primary,
          borderWidth: 3,
          name: 'Consommation',
        ),
      ],
      tooltipBehavior: TooltipBehavior(
        enable: true,
        format: 'point.x : point.y kWh',
      ),
      zoomPanBehavior: ZoomPanBehavior(
        enablePinching: true,
        enablePanning: true,
        enableMouseWheelZooming: true,
      ),
    );
  }
  
  Widget _buildTemperatureChart() {
    if (_tempData.isEmpty) {
      return const Center(child: Text('Aucune donnée disponible'));
    }
  
    return SfCartesianChart(
      primaryXAxis: DateTimeAxis(
        dateFormat: DateFormat('dd/MM HH:mm'),
        intervalType: DateTimeIntervalType.auto,
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: 'Température (°C)'),
      ),
      series: <CartesianSeries<TemperatureModel, DateTime>>[  // Change from ChartSeries to CartesianSeries
        LineSeries<TemperatureModel, DateTime>(
          dataSource: _tempData,
          xValueMapper: (data, _) => data.createdAt,
          yValueMapper: (data, _) => data.temperature,
          color: Colors.orange,
          width: 3,
          name: 'Température',
          markerSettings: const MarkerSettings(
            isVisible: true,
            shape: DataMarkerType.circle,
          ),
        ),
      ],
      tooltipBehavior: TooltipBehavior(
        enable: true,
        format: 'point.x : point.y °C',
      ),
      zoomPanBehavior: ZoomPanBehavior(
        enablePinching: true,
        enablePanning: true,
        enableMouseWheelZooming: true,
      ),
    );
  }
  
  Widget _buildHumidityChart() {
    if (_humData.isEmpty) {
      return const Center(child: Text('Aucune donnée disponible'));
    }
  
    return SfCartesianChart(
      primaryXAxis: DateTimeAxis(
        dateFormat: DateFormat('dd/MM HH:mm'),
        intervalType: DateTimeIntervalType.auto,
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: 'Humidité (%)'),
        minimum: 0,
        maximum: 100,
      ),
      series: <CartesianSeries<HumidityModel, DateTime>>[  // Change from ChartSeries to CartesianSeries
        SplineSeries<HumidityModel, DateTime>(
          dataSource: _humData,
          xValueMapper: (data, _) => data.createdAt,
          yValueMapper: (data, _) => data.humidity,
          color: Colors.blue,
          width: 3,
          name: 'Humidité',
          markerSettings: const MarkerSettings(
            isVisible: true,
            shape: DataMarkerType.circle,
          ),
        ),
      ],
      tooltipBehavior: TooltipBehavior(
        enable: true,
        format: 'point.x : point.y %',
      ),
      zoomPanBehavior: ZoomPanBehavior(
        enablePinching: true,
        enablePanning: true,
        enableMouseWheelZooming: true,
      ),
    );
  }
}