import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:aricie/theme/app_theme.dart';
import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/core/utils/energy_analysis.dart';
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
  List<DailyConsumption> _dailySeries = [];
  PeakInfo? _peak;
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
      (data) {
        _energyHistory = data;
        _dailySeries = aggregateByDay(data);
        _peak = detectPeak(_dailySeries);
      },
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
                    _buildPeakCard(),
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
      final dateKey = _selectedTimeFrame == 'Année'
          ? '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}'
          : e.date.toIso8601String();
      grouped.putIfAbsent(dateKey, () => []).add(e);
    }

    final sortedKeys = grouped.keys.toList()..sort();
    final spots = <FlSpot>[];
    double maxY = 0;
    int peakIndex = 0;
    double peakValue = -1;

    final maxPoints = sortedKeys.length;

    for (int i = 0; i < maxPoints; i++) {
      final total = grouped[sortedKeys[i]]!.fold<double>(
        0.0,
        (sum, e) => sum + e.kwh,
      );
      spots.add(FlSpot(i.toDouble(), total));
      if (total > maxY) maxY = total;
      if (total > peakValue) {
        peakValue = total;
        peakIndex = i;
      }
    }

    if (spots.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: const Center(child: Text('Aucune donnée disponible pour cette période')),
        ),
      );
    }

    maxY = maxY * 1.1;

    final displayKeys = sortedKeys.toList();

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
                          if (value.toInt() >= displayKeys.length || value.toInt() < 0) {
                            return const SizedBox();
                          }
                          final key = displayKeys[value.toInt()];
                          final label = _selectedTimeFrame == 'Année'
                              ? key.split('-').skip(1).join('/')
                              : (() {
                                  final parsed = DateTime.tryParse(key);
                                  return parsed != null ? '${parsed.day}/${parsed.month}' : key;
                                })();
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
                  maxX: displayKeys.length - 1.0,
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        // Met en évidence le jour de pic (point le plus haut).
                        getDotPainter: (spot, percent, bar, index) {
                          final isPeak =
                              maxPoints > 1 && index == peakIndex;
                          return FlDotCirclePainter(
                            radius: isPeak ? 6 : 3,
                            color: isPeak
                                ? AppColors.accentCoral
                                : Theme.of(context).colorScheme.primary,
                            strokeWidth: isPeak ? 2 : 0,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
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



  static const List<String> _frenchMonths = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];

  String _formatDay(DateTime d) =>
      '${d.day} ${_frenchMonths[d.month - 1]} ${d.year}';

  /// Carte « pic de consommation » : met en évidence le jour le plus élevé de
  /// la période pour aider le gestionnaire à détecter les pics.
  Widget _buildPeakCard() {
    final peak = _peak;
    // Un pic n'a de sens que sur une série d'au moins deux jours.
    if (peak == null || _dailySeries.length < 2) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final aboveAvg = peak.percentAboveAverage;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s6),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s3),
                decoration: BoxDecoration(
                  color: AppColors.accentCoral.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: AppColors.accentCoral,
                ),
              ),
              const SizedBox(width: AppSpacing.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jour de pic',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      _formatDay(peak.peak.day),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      aboveAvg > 0
                          ? '${aboveAvg.toStringAsFixed(0)} % au-dessus de la moyenne '
                              '(${peak.average.toStringAsFixed(1)} kWh/j)'
                          : 'Consommation régulière sur la période',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${peak.peak.kwh.toStringAsFixed(1)} kWh',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentCoral,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
