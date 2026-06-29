import 'dart:async';

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  final Map<String, RealtimePowerReading> _liveReadings = {};
  StreamSubscription<RealtimePowerReading>? _powerSub;

  double _temperature = 0.0;
  double _humidity = 0.0;

  String? _userId;
  StreamSubscription<BoxTelemetry>? _telemetrySub;
  List<FlSpot> _weeklySpots = [];

  String? _tipText;
  StreamSubscription<EnergyTipEvent>? _tipSub;
  Timer? _autoClearTimer;

  @override
  void initState() {
    super.initState();
    _mqttService = sl<MqttService>();
    TipsRealtimeService.instance.start();
    _loadDailyTip();
    _tipSub = TipsRealtimeService.instance.stream.listen((e) {
      if (!mounted) return;
      setState(() => _tipText = e.body);
      _autoClearTimer?.cancel();
      _autoClearTimer = Timer(const Duration(hours: 24), () {
        if (!mounted) return;
        _loadDailyTip();
      });
    });
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

  Future<void> _loadDailyTip() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _useFallback();
      return;
    }
    final res = await Supabase.instance.client
        .from('daily_energy_tip')
        .select('body')
        .eq('user_id', userId)
        .maybeSingle();

    if (!mounted) return;
    if (res != null) {
      setState(() => _tipText = res['body'] as String);
    } else {
      _useFallback();
    }
  }

  void _useFallback() {
    const tips = [
      'Réduisez votre consommation en éteignant les appareils en veille',
      'Réglez votre chauffe-eau à 55°C : l\'équilibre idéal entre confort et économies',
      'Dégivrez votre frigo régulièrement pour éviter 30% de surconsommation',
      'Lavez à 30°C : 3× moins d\'énergie qu\'à 60°C',
      'Débranchez les chargeurs inutilisés, ils consomment même à vide',
      'Préférez le séchage à l\'air libre plutôt que le sèche-linge',
      'Remplacez vos ampoules par des LED : 85% d\'économie',
    ];
    final day = DateTime.now().day;
    final idx = (day - 1) % tips.length;
    setState(() => _tipText = tips[idx]);
  }

  void _initRealtimePower() {
    final uid = _userId;
    if (uid == null) return;
    RealtimePowerService.instance.start(uid);
    _powerSub?.cancel();
    _powerSub = RealtimePowerService.instance.stream.listen((r) {
      if (!mounted) return;
      setState(() => _liveReadings[r.applianceId] = r);
    });
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    _powerSub?.cancel();
    _tipSub?.cancel();
    _autoClearTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                            '+5%',
                            AppColors.accentDot,
                            Icons.arrow_upward,
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
                            if (_tipText != null)
                              _buildTipCard(
                                _tipText!,
                                Icons.lightbulb_outline,
                                AppColors.accentGold.withValues(alpha: 0.3),
                                AppColors.accentGold,
                              ),
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

  Widget _buildTipCard(String tip, IconData icon, Color backgroundColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [AppShadows.sm],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s3),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: AppSpacing.s4),
          Expanded(
            child: Text(
              tip,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
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

