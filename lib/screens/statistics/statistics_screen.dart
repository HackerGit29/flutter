import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:aricie/theme/app_theme.dart';
import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/domain/entities/energy_data.dart';
import 'package:aricie/domain/entities/appliance.dart';
import 'package:aricie/domain/usecases/auth/get_current_user.dart';
import 'package:aricie/domain/usecases/devices/get_energy_data.dart';
import 'package:aricie/domain/usecases/devices/get_user_appliances.dart';
import 'package:aricie/widgets/live_consumption_indicator.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final GetEnergyHistory _getEnergyHistory = GetEnergyHistory(sl());
  final GetEnergyByAppliance _getEnergyByAppliance = GetEnergyByAppliance(sl());
  final GetUserAppliances _getUserAppliances = GetUserAppliances(sl());

  String _selectedTimeFrame = 'Jour';
  final List<String> _timeFrames = ['Jour', 'Semaine', 'Mois', 'Année'];

  List<EnergyData> _energyHistory = [];
  Map<String, double> _applianceEnergy = {};
  List<Appliance> _appliances = [];
  double _totalConsumption = 0.0;
  String? _userId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final userResult = await GetCurrentUser(sl()).call();
    final user = userResult.getOrElse(() => null);
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    _userId = user.id;

    await Future.wait([
      _loadEnergyHistory(user.id),
      _loadEnergyByAppliance(user.id),
      _loadAppliances(user.id),
    ]);

    setState(() => _isLoading = false);
  }

  Future<void> _loadEnergyHistory(String userId) async {
    final result = await _getEnergyHistory.call(
      userId: userId,
      timeFrame: _selectedTimeFrame,
    );
    result.fold(
      (_) {},
      (data) => _energyHistory = data,
    );
  }

  Future<void> _loadEnergyByAppliance(String userId) async {
    final result = await _getEnergyByAppliance.call(
      userId: userId,
      timeFrame: _selectedTimeFrame,
    );
    result.fold(
      (_) {},
      (data) {
        _applianceEnergy = data;
        _totalConsumption = data.values.fold(0.0, (a, b) => a + b);
      },
    );
  }

  Future<void> _loadAppliances(String userId) async {
    final result = await _getUserAppliances.call();
    result.fold(
      (_) {},
      (data) => _appliances = data,
    );
  }

  void _changeTimeFrame(String timeFrame) {
    setState(() => _selectedTimeFrame = timeFrame);
    _loadData();
  }

  String _applianceName(String id) {
    final appliance = _appliances.where((a) => a.id == id).firstOrNull;
    return appliance?.name ?? 'Appareil #${id.substring(0, 6)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques de consommation'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTimeFrameSelector(),
                    const SizedBox(height: AppSpacing.s4),
                    if (_userId != null) LiveConsumptionIndicator(userId: _userId!),
                    const SizedBox(height: AppSpacing.s6),
                    _buildCurrentConsumptionCard(),
                    const SizedBox(height: AppSpacing.s6),
                    _buildConsumptionChart(),
                    const SizedBox(height: AppSpacing.s6),
                    _buildDeviceDetails(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTimeFrameSelector() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: _timeFrames.map((timeFrame) {
          final isSelected = timeFrame == _selectedTimeFrame;
          return Expanded(
            child: GestureDetector(
              onTap: () => _changeTimeFrame(timeFrame),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                alignment: Alignment.center,
                child: Text(
                  timeFrame,
                  style: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCurrentConsumptionCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Consommation totale',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.s2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _totalConsumption.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.s1),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'kWh',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'Période: $_selectedTimeFrame',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsumptionChart() {
    if (_energyHistory.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: const Center(
            child: Text('Aucune donnée disponible pour cette période'),
          ),
        ),
      );
    }

    final Map<String, List<EnergyData>> grouped = {};
    for (final e in _energyHistory) {
      final dateKey = e.date.toIso8601String();
      grouped.putIfAbsent(dateKey, () => []).add(e);
    }

    final sortedDates = grouped.keys.toList()..sort();
    final spots = <FlSpot>[];
    double maxY = 0;

    for (int i = 0; i < sortedDates.length && i < 10; i++) {
      final total = grouped[sortedDates[i]]!.fold<double>(
        0.0,
        (sum, e) => sum + _timeFrameValue(e),
      );
      spots.add(FlSpot(i.toDouble(), total));
      if (total > maxY) maxY = total;
    }

    maxY = maxY * 1.1;

    final displayDates = sortedDates.take(10).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Évolution de la consommation',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.s4),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 5,
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= displayDates.length || value.toInt() < 0) {
                            return const SizedBox();
                          }
                          final dateStr = displayDates[value.toInt()];
                          final parsed = DateTime.tryParse(dateStr);
                          final label = parsed != null
                              ? '${parsed.day}/${parsed.month}'
                              : dateStr;
                          return SideTitleWidget(
                            meta: meta,
                            space: 4,
                            child: Text(
                              label,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: maxY / 5,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              value.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: AppColors.textPrimary, width: 1),
                  ),
                  minX: 0,
                  maxX: displayDates.length - 1.0,
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _timeFrameValue(EnergyData e) {
    switch (_selectedTimeFrame) {
      case 'Jour': return e.totalDay;
      case 'Semaine': return e.totalWeek;
      case 'Mois': return e.totalMonth;
      case 'Année': return e.totalYear;
      default: return e.totalDay;
    }
  }

  Widget _buildDeviceDetails() {
    if (_applianceEnergy.isEmpty) {
      return const SizedBox();
    }

    final colors = [
      AppColors.accentBlue,
      AppColors.accentCoral,
      AppColors.accentMint,
    ];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Consommation par appareil',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.s4),
            ..._applianceEnergy.entries.toList().asMap().entries.map((entry) {
              final i = entry.key;
              final applianceEntry = entry.value;
              return Column(
                children: [
                  if (i > 0) const Divider(),
                  _buildDeviceConsumptionItem(
                    _applianceName(applianceEntry.key),
                    applianceEntry.value,
                    colors[i % colors.length],
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceConsumptionItem(String name, double value, Color color) {
    final percentage = _totalConsumption > 0 ? (value / _totalConsumption * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                '${value.toStringAsFixed(1)} kWh',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Stack(
            children: [
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),
              Container(
                height: 8,
                width: MediaQuery.of(context).size.width * percentage / 100 * 0.8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
