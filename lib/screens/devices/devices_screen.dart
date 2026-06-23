import 'dart:async';

import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/domain/usecases/devices/get_user_appliances.dart';
import 'package:aricie/domain/usecases/devices/toggle_device.dart';
import 'package:aricie/domain/usecases/devices/add_device.dart';
import 'package:aricie/domain/usecases/devices/remove_device.dart';
import 'package:aricie/domain/entities/appliance.dart';
import 'package:aricie/services/mqtt_service.dart';
import 'package:aricie/models/box_telemetry.dart';
import 'package:aricie/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:mqtt5_client/mqtt5_client.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../widgets/common_header.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen>
    with SingleTickerProviderStateMixin {
  final _mqttService = MqttService();
  List<Appliance> _appliances = [];
  bool _isLoading = true;
  late TabController _tabController;

  final Map<String, bool> _deviceStates = {};

  List<StreamSubscription> _subscriptions = [];
  final List<String> _categories = [
    'Tous', 'Salon', 'Cuisine', 'Chambre', 'Autres',
  ];
  String _selectedCategory = 'Tous';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedCategory = _categories[_tabController.index];
        });
      }
    });

    _initializeMqtt();
    _loadAppliances();
  }

  Future<void> _initializeMqtt() async {
    await _mqttService.initialize(
      boxUid: '',
      mqttToken: '',
    );

    final latest = _mqttService.latestTelemetry;
    if (latest != null) {
      _updateDeviceStates(latest);
    }

    _subscriptions.add(
      _mqttService.telemetryStream.listen(_updateDeviceStates)
    );
  }

  void _updateDeviceStates(BoxTelemetry telemetry) {
    setState(() {
      for (final relay in telemetry.relays) {
        _deviceStates[relay.index.toString()] = relay.isOn;
      }
    });
  }

  @override
  void dispose() {
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _tabController.dispose();
    super.dispose();
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

  Future<void> _addDevice() async {
    final nameController = TextEditingController();
    String selectedLocation = 'Salon';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          title: const Text('Ajouter un boîtier'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nom du boîtier',
                  hintText: 'Ex: Boîtier cuisine',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  prefixIcon: const Icon(Icons.devices),
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              DropdownButtonFormField<String>(
                initialValue: selectedLocation,
                decoration: InputDecoration(
                  labelText: 'Emplacement',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  prefixIcon: const Icon(Icons.location_on),
                ),
                items: ['Salon', 'Cuisine', 'Chambre', 'Salle de bain', 'Bureau', 'Autres']
                  .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
                  .toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedLocation = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      final name = nameController.text.trim();
      if (name.isNotEmpty) {
        final addResult = await AddDevice(sl()).call(name, selectedLocation);
        addResult.fold(
          (failure) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erreur: ${failure.message}'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              );
            }
          },
          (_) async {
            await _loadAppliances();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Boîtier "$name" ajouté avec succès'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              );
            }
          },
        );
      }
    }
  }

  Future<void> _deleteAppliance(Appliance appliance) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        title: const Text('Confirmer la suppression'),
        content: Text('Supprimer tout le boîtier contenant "${appliance.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentDot,
              foregroundColor: AppColors.textInverse,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final result = await RemoveDevice(sl()).call(appliance.boxId);
      result.fold(
        (failure) {
          debugPrint('Error deleting box: ${failure.message}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Erreur lors de la suppression'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            );
          }
        },
        (_) async {
          await _loadAppliances();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Boîtier "${appliance.name}" supprimé'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            );
          }
        },
      );
    }
  }

  Future<void> _toggleAppliance(Appliance appliance, bool newState) async {
    final relayIndex = appliance.relayIndex;

    bool isConnected = await _checkMqttConnection();
    if (!isConnected) {
      await _mqttService.initialize(
        boxUid: appliance.boxUid ?? '',
        mqttToken: '',
      );
      isConnected = await _checkMqttConnection();
      if (!isConnected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erreur de connexion au broker MQTT'),
              backgroundColor: AppColors.textInverse,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    }

    await _mqttService.sendDebugControlCommand(
      boxUid: appliance.boxUid ?? '',
      relayIndex: relayIndex,
      action: newState ? 'on' : 'off',
    );

    setState(() {
      _deviceStates[relayIndex.toString()] = newState;
    });

    await ToggleDevice(sl()).call(appliance.id, newState);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${newState ? 'Activation' : 'Désactivation'} de ${appliance.name}...'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        ),
      );
    }
  }

  Future<bool> _checkMqttConnection() async {
    Completer<bool> completer = Completer<bool>();

    StreamSubscription? subscription;
    subscription = _mqttService.connectionState.listen((state) {
      if (state == MqttConnectionState.connected) {
        subscription?.cancel();
        if (!completer.isCompleted) completer.complete(true);
      } else if (state == MqttConnectionState.disconnected) {
        subscription?.cancel();
        if (!completer.isCompleted) completer.complete(false);
      }
    });

    Future.delayed(const Duration(seconds: 2), () {
      subscription?.cancel();
      if (!completer.isCompleted) completer.complete(false);
    });

    return completer.future;
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
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: AppColors.textPrimary.withValues(alpha: 0.7),
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                tabs: _categories.map((cat) => Tab(text: cat)).toList(),
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
                    : AnimationLimiter(
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
                            return AnimationConfiguration.staggeredGrid(
                              position: index,
                              duration: const Duration(milliseconds: 375),
                              columnCount: 2,
                              child: ScaleAnimation(
                                child: FadeInAnimation(
                                  child: _buildApplianceCard(appliance),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDevice,
        child: const Icon(Icons.add),
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
              ? 'Ajoutez des boîtiers pour commencer'
              : 'Aucun appareil dans cette catégorie',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: AppSpacing.s6),
          ElevatedButton.icon(
            onPressed: _addDevice,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un boîtier'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplianceCard(Appliance appliance) {
    final relayIndex = appliance.relayIndex;
    final bool isActive = _deviceStates[relayIndex.toString()] ?? false;

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
    final relayIndex = appliance.relayIndex;
    final bool isActive = _deviceStates[relayIndex.toString()] ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
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
                      child: Icon(_getApplianceIcon(appliance.name),
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
                      onChanged: (value) {
                        _toggleAppliance(appliance, value);
                        Navigator.pop(context);
                      },
                      activeThumbColor: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildActionButton('Programmer', Icons.schedule, AppColors.textInverse, () {}),
                        const SizedBox(width: AppSpacing.s4),
                        _buildActionButton('Historique', Icons.history, AppColors.textInverse, () {}),
                        const SizedBox(width: AppSpacing.s4),
                        _buildActionButton('Supprimer', Icons.delete, AppColors.textInverse, () {
                          Navigator.pop(context);
                          _deleteAppliance(appliance);
                        }),
                      ],
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

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(label,
              style: TextStyle(color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  IconData _getApplianceIcon(String name) {
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
}
