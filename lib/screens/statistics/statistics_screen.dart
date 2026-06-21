import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:aricie/theme/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../models/energy_data_model.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  String _selectedTimeFrame = 'Jour';
  final List<String> _timeFrames = ['Jour', 'Semaine', 'Mois', 'Année'];
  
  // Données pour les graphiques
  List<Map<String, dynamic>> _energyHistory = [];
  Map<String, dynamic> _currentConsumption = {'value': 0.0, 'unit': 'kWh'};
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Écouter les mises à jour en temps réel
    _supabaseService.energyConsumption.addListener(_onEnergyDataUpdated);
  }
  
  @override
  void dispose() {
    _supabaseService.energyConsumption.removeListener(_onEnergyDataUpdated);
    super.dispose();
  }
  
  void _onEnergyDataUpdated() {
    // Mettre à jour les données actuelles quand de nouvelles données arrivent
    _loadCurrentConsumption();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    await Future.wait([
      _loadCurrentConsumption(),
      _loadEnergyHistory(),
    ]);
    
    setState(() {
      _isLoading = false;
    });
  }
  
  Future<void> _loadCurrentConsumption() async {
    final consumption = await _supabaseService.getEnergyConsumption(_selectedTimeFrame);
    
    setState(() {
      _currentConsumption = consumption;
    });
  }
  
  Future<void> _loadEnergyHistory() async {
    final history = await _supabaseService.getEnergyConsumptionHistory(_selectedTimeFrame);
    
    setState(() {
      _energyHistory = history;
    });
  }
  
  void _changeTimeFrame(String timeFrame) {
    setState(() {
      _selectedTimeFrame = timeFrame;
    });
    _loadData();
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
                    // Sélecteur de période
                    _buildTimeFrameSelector(),
                    const SizedBox(height: AppSpacing.s6),
                    
                    // Carte de consommation actuelle
                    _buildCurrentConsumptionCard(),
                    const SizedBox(height: AppSpacing.s6),
                    
                    // Graphique de consommation
                    _buildConsumptionChart(),
                    const SizedBox(height: AppSpacing.s6),
                    
                    // Détails des appareils
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
                  _currentConsumption['value'].toStringAsFixed(1),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.s1),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _currentConsumption['unit'],
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
    
    // Préparer les données pour le graphique
    final List<FlSpot> spots = [];
    double maxY = 0;
    
    // Déterminer le champ à utiliser en fonction de la période
    String valueField;
    switch (_selectedTimeFrame) {
      case 'Jour':
        valueField = 'total_day';
        break;
      case 'Semaine':
        valueField = 'total_week';
        break;
      case 'Mois':
        valueField = 'total_month';
        break;
      case 'Année':
        valueField = 'total_year';
        break;
      default:
        valueField = 'total_day';
    }
    
    // Limiter à 10 points de données pour la lisibilité
    final displayData = _energyHistory.take(10).toList();
    
    for (int i = 0; i < displayData.length; i++) {
      final value = (displayData[i][valueField] ?? 0.0) as double;
      spots.add(FlSpot(i.toDouble(), value));
      if (value > maxY) maxY = value;
    }
    
    // Ajouter 10% à la valeur maximale pour l'espace
    maxY = maxY * 1.1;
    
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
                          if (value.toInt() >= displayData.length || value.toInt() < 0) {
                            return const SizedBox();
                          }
                          
                          String label = '';
                          final data = displayData[value.toInt()];
                          switch (_selectedTimeFrame) {
                            case 'Jour':
                              if (data['date'] != null) {
                                final date = DateTime.parse(data['date']);
                                label = '${date.day}/${date.month}';
                              }
                              break;
                            case 'Semaine':
                              label = 'S${data['week']}';
                              break;
                            case 'Mois':
                              final monthNames = ['', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
                              label = monthNames[data['month'] ?? 0];
                              break;
                            case 'Année':
                              label = '${data['year']}';
                              break;
                            default:
                              label = '$value';
                          }
                          
                          return SideTitleWidget(
                              meta: meta,
                            space: 4,
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 10,
                              ),
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
                              style: const TextStyle(
                                fontSize: 10,
                              ),
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
                  maxX: displayData.length - 1.0,
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
  
  Widget _buildDeviceDetails() {
    // Récupérer les dernières données des appareils
    final latestData = _energyHistory.isNotEmpty ? _energyHistory.first : null;
    
    if (latestData == null) {
      return const SizedBox();
    }
    
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
            _buildDeviceConsumptionItem(
              'Appareil 1',
              latestData['device1'] ?? 0.0,
              AppColors.accentBlue,
            ),
            const Divider(),
            _buildDeviceConsumptionItem(
              'Appareil 2',
              latestData['device2'] ?? 0.0,
              AppColors.accentCoral,
            ),
            const Divider(),
            _buildDeviceConsumptionItem(
              'Appareil 3',
              latestData['device3'] ?? 0.0,
              AppColors.accentMint,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDeviceConsumptionItem(String name, double value, Color color) {
    // Calculer le pourcentage par rapport à la consommation totale
    final totalValue = _currentConsumption['value'] as double;
    final percentage = totalValue > 0 ? (value / totalValue * 100) : 0.0;
    
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
