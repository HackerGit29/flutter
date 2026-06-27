import 'dart:async';

import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/domain/usecases/devices/get_user_appliances.dart';
import 'package:aricie/domain/usecases/devices/toggle_device.dart';
import 'package:aricie/domain/entities/appliance.dart';
import 'package:aricie/models/box_telemetry.dart';
import 'package:aricie/services/mqtt_service.dart';
import 'package:aricie/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../../widgets/common_header.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  List<Appliance> _appliances = [];
  bool _isLoading = true;

  String _selectedCategory = 'Tous';

  StreamSubscription<Map<int, RelayState>>? _relayStateSub;

  List<String> get _categories {
    final locs = _appliances
      .map((a) => a.location)
      .whereType<String>()
      .where((l) => l.isNotEmpty)
      .toSet()
      .toList();
    locs.sort();
    return ['Tous', ...locs];
  }

  @override
  void initState() {
    super.initState();
    _loadAppliances();
    _relayStateSub = sl<MqttService>().relayStatesStream.listen(_onRelayStates);
  }

  @override
  void dispose() {
    _relayStateSub?.cancel();
    super.dispose();
  }

  void _onRelayStates(Map<int, RelayState> relayStates) {
    if (!mounted) return;
    var changed = false;
    final updated = _appliances.map((a) {
      final relay = relayStates[a.relayIndex];
      if (relay != null && relay.isOn != a.isOn) {
        changed = true;
        return a.copyWith(isOn: relay.isOn);
      }
      return a;
    }).toList();
    if (changed) {
      setState(() => _appliances = updated);
    }
  }

  Future<void> _loadAppliances() async {
    setState(() => _isLoading = true);
    final result = await GetUserAppliances(sl()).call();
    result.fold(
      (failure) {
        debugPrint('Error loading appliances: ${failure.message}');
        setState(() => _isLoading = false);
      },
      (appliances) {
        setState(() {
          _appliances = appliances;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _toggleAppliance(Appliance appliance, bool newState) async {
    setState(() {
      final idx = _appliances.indexWhere((a) => a.id == appliance.id);
      if (idx >= 0) {
        _appliances[idx] = appliance.copyWith(isOn: newState);
      }
    });
    final result = await ToggleDevice(sl()).call(appliance.id, newState);
    result.fold(
      (failure) {
        debugPrint('Toggle error: ${failure.message}');
        _loadAppliances();
      },
      (_) {},
    );
  }

  List<Appliance> _getFilteredAppliances() {
    if (_selectedCategory == 'Tous') return _appliances;
    return _appliances
        .where((a) => a.location == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAppliances = _getFilteredAppliances();
    final categories = _categories;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.s2),
              CommonHeader(title: 'Mes Appareils'),
              const SizedBox(height: AppSpacing.s6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((cat) {
                    final selected = cat == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.s2),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: selected,
                        onSelected: (v) {
                          setState(() => _selectedCategory = cat);
                        },
                        selectedColor: Theme.of(context).colorScheme.primaryContainer,
                        labelStyle: TextStyle(
                          color: selected
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : AppColors.textPrimary.withValues(alpha: 0.7),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                '${filteredAppliances.length} appareil${filteredAppliances.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Expanded(
                child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredAppliances.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadAppliances,
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: AppSpacing.s4,
                            mainAxisSpacing: AppSpacing.s4,
                          ),
                          itemCount: filteredAppliances.length,
                          itemBuilder: (context, index) {
                            final appliance = filteredAppliances[index];
                            return _buildApplianceCard(appliance);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s6),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.devices_other, size: 48,
              color: AppColors.interactive.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: AppSpacing.s6),
          Text('Aucun appareil trouvé',
            style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.s2),
          Text(
            _selectedCategory == 'Tous'
              ? 'Aucun appareil connecté. Contactez votre administrateur.'
              : 'Aucun appareil dans cette catégorie',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildApplianceCard(Appliance appliance) {
    final bool isActive = appliance.isOn;

    return GestureDetector(
      onTap: () => _showApplianceDetails(appliance),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: const [AppShadows.md],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s4),
              decoration: BoxDecoration(
                color: isActive
                  ? AppColors.interactive.withValues(alpha: 0.1)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg),
                  topRight: Radius.circular(AppRadius.lg),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s3),
                    decoration: BoxDecoration(
                      color: isActive
                        ? AppColors.interactive.withValues(alpha: 0.2)
                        : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      _getApplianceIcon(appliance.name),
                      color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : AppColors.textPrimary.withValues(alpha: 0.6),
                      size: 24,
                    ),
                  ),
                  Switch(
                    value: isActive,
                    onChanged: (value) => _toggleAppliance(appliance, value),
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appliance.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.s1),
                  if (appliance.location != null)
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14,
                          color: AppColors.textPrimary.withValues(alpha: 0.6)),
                        const SizedBox(width: AppSpacing.s1),
                        Text(appliance.location!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textPrimary.withValues(alpha: 0.6))),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.s2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: AppSpacing.s1),
                    decoration: BoxDecoration(
                      color: isActive
                        ? AppColors.interactive.withValues(alpha: 0.1)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      isActive ? 'Actif' : 'Inactif',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : AppColors.textPrimary.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showApplianceDetails(Appliance appliance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ApplianceDetailContent(
        appliance: appliance,
        onToggle: (value) => _toggleAppliance(appliance, value),
      ),
    );
  }

  IconData _getApplianceIcon(String name) => getApplianceIcon(name);
}

IconData getApplianceIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('ventilateur')) return Icons.air;
  if (n.contains('télévision') || n.contains('television') || n.contains('tv')) return Icons.tv;
  if (n.contains('frigo') || n.contains('congélateur') || n.contains('congelateur')) return Icons.kitchen;
  if (n.contains('lumière') || n.contains('ampoule') || n.contains('lampe')) return Icons.lightbulb;
  if (n.contains('chauffage')) return Icons.whatshot;
  if (n.contains('climatiseur') || n.contains('clim')) return Icons.ac_unit;
  if (n.contains('lave') || n.contains('machine')) return Icons.local_laundry_service;
  if (n.contains('four')) return Icons.microwave;
  return Icons.devices_other;
}

class _ApplianceDetailContent extends StatelessWidget {
  final Appliance appliance;
  final ValueChanged<bool> onToggle;

  const _ApplianceDetailContent({
    required this.appliance,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<int, RelayState>>(
      stream: sl<MqttService>().relayStatesStream,
      builder: (context, snapshot) {
        final relayState = snapshot.data?[appliance.relayIndex];
        final isActive = appliance.isOn;
        final powerW = relayState?.powerW;
        final isLive = relayState != null;

        return Container(
          height: MediaQuery.of(context).size.height * 0.5,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadius.xl),
              topRight: Radius.circular(AppRadius.xl),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: AppSpacing.s3),
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.s6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.s3),
                        decoration: BoxDecoration(
                          color: isActive
                            ? AppColors.interactive.withValues(alpha: 0.1)
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(getApplianceIcon(appliance.name),
                          color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : AppColors.textPrimary.withValues(alpha: 0.6),
                          size: 32),
                      ),
                      const SizedBox(width: AppSpacing.s4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(appliance.name,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold)),
                            if (appliance.location != null)
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 16,
                                    color: AppColors.textPrimary.withValues(alpha: 0.6)),
                                  const SizedBox(width: AppSpacing.s1),
                                  Text(appliance.location!,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textPrimary.withValues(alpha: 0.6))),
                                ],
                              ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isActive,
                        onChanged: onToggle,
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
                if (isLive)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
                    child: Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: isActive
                              ? const Color(0xFF4CAF50)
                              : AppColors.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s2),
                        Text('En direct',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s6, AppSpacing.s4, AppSpacing.s6, AppSpacing.s6,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.s5),
                    decoration: BoxDecoration(
                      color: isActive
                        ? AppColors.interactive.withValues(alpha: 0.08)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Consommation en temps réel',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.textPrimary.withValues(alpha: 0.7))),
                        const SizedBox(height: AppSpacing.s2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              powerW != null
                                ? '${powerW.toStringAsFixed(1)} W'
                                : '— W',
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isActive
                                  ? Theme.of(context).colorScheme.primary
                                  : AppColors.textPrimary.withValues(alpha: 0.5)),
                            ),
                            if (!isLive)
                              Padding(
                                padding: const EdgeInsets.only(left: AppSpacing.s2, bottom: 4),
                                child: Text('(en attente du boîtier)',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textMuted)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
