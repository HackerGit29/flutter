import 'dart:async';

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:aricie/theme/app_theme.dart';
import 'package:aricie/core/constants.dart';
import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/domain/entities/appliance.dart';
import 'package:aricie/domain/usecases/auth/get_current_user.dart';
import 'package:aricie/domain/usecases/devices/get_user_devices.dart';
import 'package:aricie/domain/usecases/devices/get_user_appliances.dart';
import 'package:aricie/domain/usecases/devices/get_energy_data.dart';
import 'package:aricie/services/mqtt_service.dart';
import 'package:aricie/services/update_service.dart';
import 'package:aricie/services/realtime_power_service.dart';
import 'package:aricie/models/box_telemetry.dart';
import 'statistics/statistics_screen.dart';
import 'devices/devices_screen.dart';
import 'settings/settings_screen.dart';
import 'update/update_screen.dart';
import '../widgets/chatbot_floating_button.dart';
import '../services/tips_realtime_service.dart';
import '../widgets/daily_energy_tip_banner.dart';

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
  void initState() {
    super.initState();
    // Vérification de mise à jour post-authentification (cooldown 24h).
    // Si une MAJ est trouvée, une notification locale est envoyée ET
    // l'UpdateScreen s'affiche automatiquement.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    // checkForUpdateIfNeeded gère le cooldown 24h et la notification.
    // On s'abonne aussi au stream pour naviguer vers UpdateScreen.
    UpdateService.instance.onUpdate((info) {
      if (info.updateAvailable && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UpdateScreen(updateInfo: info),
          ),
        );
      }
    });
    await UpdateService.instance.checkForUpdateIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
          const ChatbotFloatingButton(),
        ],
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

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  late final MqttService _mqttService;
  bool _isLoading = true;

  List<Appliance> _appliances = [];
  Map<String, double> _applianceEnergy = {};
  double _totalConsumption = 0.0;
  // Variation de la conso du jour vs la veille (en %). null si indéterminable.
  double? _dailyTrendPercent;
  // Conso de la veille (kWh) mémorisée pour recalculer la tendance en direct.
  double? _yesterdayKwh;
  // Index du point « aujourd'hui » dans _weeklySpots (null si absent de l'historique).
  int? _todaySpotIndex;

  final Map<String, RealtimePowerReading> _liveReadings = {};
  StreamSubscription<RealtimePowerReading>? _powerSub;

  double _temperature = 0.0;
  double _humidity = 0.0;

  String? _userId;
  StreamSubscription<BoxTelemetry>? _telemetrySub;
  List<FlSpot> _weeklySpots = [];

  @override
  void initState() {
    super.initState();
    _mqttService = sl<MqttService>();
    // Le conseil du jour + les pushes live sont gérés par DailyEnergyTipBanner.
    TipsRealtimeService.instance.start();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final userResult = await GetCurrentUser(sl()).call();
    final user = userResult.getOrElse(() => null);
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    _userId = user.id;

    await Future.wait([
      _loadBoxes(),
      _loadAppliances(),
      _loadEnergy(),
    ]);

    await _initMqttService();
    _initRealtimePower();

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadBoxes() async {
    final result = await GetUserDevices(sl()).call();
    result.fold((_) {}, (_) {});
  }

  Future<void> _loadAppliances() async {
    final result = await GetUserAppliances(sl()).call();
    result.fold((_) {}, (data) => _appliances = data);
  }

  Future<void> _loadEnergy() async {
    final userResult = await GetCurrentUser(sl()).call();
    final user = userResult.getOrElse(() => null);
    if (user == null) return;

    final result = await GetEnergyByAppliance(sl()).call(
      userId: user.id,
      timeFrame: 'Jour',
    );
    result.fold((_) {}, (data) {
      _applianceEnergy = data;
      _totalConsumption = data.values.fold(0.0, (a, b) => a + b);
    });

    final historyResult = await GetEnergyHistory(sl()).call(
      userId: user.id,
      timeFrame: 'Semaine',
    );
    historyResult.fold((_) {}, (data) {
      final sorted = data..sort((a, b) => a.date.compareTo(b.date));
      _weeklySpots = List.generate(sorted.length, (i) {
        return FlSpot(i.toDouble(), sorted[i].kwh);
      });

      final now = DateTime.now();
      bool isToday(DateTime d) =>
          d.year == now.year && d.month == now.month && d.day == now.day;

      // Point « aujourd'hui » du graphe : suivra le total en direct (cf.
      // _recomputeLiveAggregates), pour que la courbe évolue avec la conso.
      final todayIdx = sorted.indexWhere((p) => isToday(p.date));
      _todaySpotIndex = todayIdx >= 0 ? todayIdx : null;

      // Conso de la veille (dernier jour antérieur à aujourd'hui) mémorisée
      // pour recalculer la tendance à chaque nouvelle valeur temps réel.
      final previousDays = sorted.where((p) => !isToday(p.date)).toList();
      _yesterdayKwh = (previousDays.isNotEmpty && previousDays.last.kwh > 0)
          ? previousDays.last.kwh
          : null;

      final y = _yesterdayKwh;
      _dailyTrendPercent =
          (y != null) ? (_totalConsumption - y) / y * 100 : null;
    });
  }

  Future<void> _initMqttService() async {
    final boxUid = _appliances.isNotEmpty
        ? _appliances.first.boxUid
        : (AppConstants.flespiDefaultBoxUid.isNotEmpty
            ? AppConstants.flespiDefaultBoxUid
            : null);
    if (boxUid == null) return;

    await _mqttService.initialize(
      boxUid: boxUid,
      mqttToken: null,
      force: true,
    );

    _telemetrySub?.cancel();
    _telemetrySub = _mqttService.telemetryStream.listen((telemetry) {
      if (mounted) {
        setState(() {
          _temperature = telemetry.temperature;
          _humidity = telemetry.humidity;
        });
      }
    });
  }

  void _initRealtimePower() {
    final uid = _userId;
    if (uid == null) return;
    RealtimePowerService.instance.start(uid);
    _powerSub?.cancel();
    _powerSub = RealtimePowerService.instance.stream.listen((r) {
      if (!mounted) return;
      setState(() {
        _liveReadings[r.applianceId] = r;
        _recomputeLiveAggregates();
      });
    });
  }

  // Recalcule les agrégats affichés (total journalier, tendance vs veille et
  // point « aujourd'hui » du graphe) à partir des lectures temps réel, avec
  // repli sur les valeurs de la base pour les appareils pas encore vus en live.
  // Même logique que les cartes par appareil, pour rester cohérent.
  void _recomputeLiveAggregates() {
    double total = 0.0;
    for (final a in _appliances) {
      final live = _liveReadings[a.id]?.powerKwh;
      total += live ?? (_applianceEnergy[a.id] ?? 0.0);
    }
    _totalConsumption = total;

    final y = _yesterdayKwh;
    _dailyTrendPercent =
        (y != null && y > 0) ? (_totalConsumption - y) / y * 100 : null;

    final idx = _todaySpotIndex;
    if (idx != null && idx >= 0 && idx < _weeklySpots.length) {
      _weeklySpots[idx] = FlSpot(idx.toDouble(), _totalConsumption);
    }
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    _powerSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (dailyChange, dailyChangeColor, dailyChangeIcon) = _dailyTrend();
    return SafeArea(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mon Tableau de Bord',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s6),
                      CarouselSlider(
                        options: CarouselOptions(
                          height: 180,
                          viewportFraction: 0.9,
                          enableInfiniteScroll: true,
                          autoPlay: true,
                          autoPlayInterval: const Duration(seconds: 5),
                          autoPlayAnimationDuration: const Duration(milliseconds: 800),
                          autoPlayCurve: Curves.fastOutSlowIn,
                          enlargeCenterPage: true,
                        ),
                        items: [
                          _buildSensorCard(
                            'Température',
                            '${_temperature.toStringAsFixed(1)}°C',
                            Icons.thermostat,
                            AppColors.accentTeal,
                            AppColors.accentBlue.withValues(alpha: 0.3),
                          ),
                          _buildSensorCard(
                            'Humidité',
                            '${_humidity.toStringAsFixed(1)}%',
                            Icons.water_drop,
                            AppColors.accentTeal,
                            AppColors.accentMint.withValues(alpha: 0.3),
                          ),
                          _buildConsumptionCard(
                            'Consommation Journalière',
                            _totalConsumption.toStringAsFixed(1),
                            dailyChange,
                            dailyChangeColor,
                            dailyChangeIcon,
                            AppColors.accentCoral.withValues(alpha: 0.3),
                            AppColors.accentCoral,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Répartition par Appareil',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const StatisticsScreen()),
                              ),
                              child: const Text('Voir plus'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.5,
                          crossAxisSpacing: AppSpacing.s4,
                          mainAxisSpacing: AppSpacing.s4,
                        ),
                        itemCount: _appliances.length,
                        itemBuilder: (context, index) {
                          final appliance = _appliances[index];
                          final reading = _liveReadings[appliance.id];
                          final consumption = reading?.powerKwh ?? _applianceEnergy[appliance.id] ?? 0.0;
                          return _buildDeviceCard(
                            appliance.name,
                            consumption.toStringAsFixed(1),
                            _getDeviceIcon(appliance.name),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.s6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tendance Hebdomadaire',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s4),
                            Container(
                              height: 200,
                              padding: const EdgeInsets.all(AppSpacing.s4),
                              decoration: BoxDecoration(
                                color: AppColors.bgPrimary,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                boxShadow: [AppShadows.sm],
                              ),
                              child: _buildWeeklyChart(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Conseils d\'économie',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s4),
                            const DailyEnergyTipBanner(),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 80,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSensorCard(String title, String value, IconData icon, Color iconColor, Color bgColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [AppShadows.sm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: AppSpacing.s2),
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: iconColor)),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value.split('°')[0].split('%')[0],
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(width: AppSpacing.s1),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  value.contains('°') ? '°C' : '%',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: AppSpacing.s1),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.update, color: iconColor, size: 16),
                    const SizedBox(width: AppSpacing.s1),
                    Text('Temps réel', style: TextStyle(color: iconColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Traduit _dailyTrendPercent en (texte, couleur, icône) pour la pastille de
  // tendance. Hausse = corail (défavorable), baisse = menthe (favorable),
  // neutre / indéterminé = gris avec une flèche plate.
  (String, Color, IconData) _dailyTrend() {
    final trend = _dailyTrendPercent;
    if (trend == null) {
      return ('—', AppColors.accentDot, Icons.trending_flat);
    }
    final pct = trend.round();
    if (pct > 0) return ('+$pct%', AppColors.accentCoral, Icons.arrow_upward);
    if (pct < 0) return ('$pct%', AppColors.accentMint, Icons.arrow_downward);
    return ('0%', AppColors.accentDot, Icons.trending_flat);
  }

  Widget _buildConsumptionCard(
    String title, String value, String change, Color changeColor,
    IconData changeIcon, Color cardColor, Color iconColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [AppShadows.sm]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.electric_bolt, color: iconColor),
            const SizedBox(width: AppSpacing.s2),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: iconColor)),
          ]),
          const SizedBox(height: AppSpacing.s4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(width: AppSpacing.s1),
              const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('kWh', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: AppSpacing.s1),
                decoration: BoxDecoration(color: changeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Row(children: [
                  Icon(changeIcon, color: changeColor, size: 16),
                  const SizedBox(width: AppSpacing.s1),
                  Text(change, style: TextStyle(color: changeColor, fontWeight: FontWeight.bold)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(String deviceName, String consumption, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(color: AppColors.bgPrimary, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: [AppShadows.sm]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
          const Spacer(),
          Text(deviceName, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: AppSpacing.s1),
          Text('$consumption kWh', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('tv') || lower.contains('télé')) return Icons.tv;
    if (lower.contains('frigo') || lower.contains('réfrigérateur')) return Icons.kitchen;
    if (lower.contains('lumière') || lower.contains('lampe')) return Icons.lightbulb;
    if (lower.contains('clim') || lower.contains('climatiseur')) return Icons.ac_unit;
    if (lower.contains('machine') || lower.contains('lave')) return Icons.local_laundry_service;
    if (lower.contains('four') || lower.contains('micro')) return Icons.microwave;
    return Icons.devices_other;
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
              getTitlesWidget: (value, meta) => Text('${value.toInt()} kWh', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
                if (value.toInt() < 0 || value.toInt() >= days.length) return const Text('');
                return Text(days[value.toInt()], style: const TextStyle(color: AppColors.textMuted, fontSize: 12));
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: _weeklySpots.isEmpty
                ? const [FlSpot(0, 0)]
                : _weeklySpots,
            isCurved: true,
            gradient: LinearGradient(colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ]),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.0),
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
}

