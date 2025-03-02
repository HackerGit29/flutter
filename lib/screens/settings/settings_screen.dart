import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../models/device_model.dart';
import '../../services/mqtt_service.dart';
import '../../widgets/common_header.dart';
import '../../providers/theme_provider.dart';
import 'device_form_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final MqttService _mqttService = MqttService();
  late AnimationController _animationController;
  List<DeviceModel> _devices = [];
  bool _isLoading = true;
  bool _isExpanded = false;

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

      final devices =
          (response as List).map((json) => DeviceModel.fromJson(json)).toList();

      setState(() => _devices = devices);
    } catch (e) {
      _showError('Erreur lors du chargement des appareils');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addDevice() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const DeviceFormDialog(),
    );

    if (result != null) {
      try {
        final user = _supabase.auth.currentUser;
        if (user == null) return;

        final newDevice = DeviceModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: result['name']!,
          location: result['location']!,
          userId: user.id,
          createdAt: DateTime.now(),
        );

        final response =
            await _supabase
                .from('devices')
                .insert(newDevice.toJson())
                .select()
                .single();

        final device = DeviceModel.fromJson(response);
        setState(() {
          _devices.insert(0, device);
        });
      } catch (e) {
        _showError('Erreur lors de l\'ajout de l\'appareil');
      }
    }
  }

  Future<void> _editDevice(DeviceModel device) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder:
          (context) => DeviceFormDialog(
            initialName: device.name,
            initialLocation: device.location,
          ),
    );

    if (result != null) {
      try {
        final updatedDevice = device.copyWith(
          name: result['name'],
          location: result['location'],
        );

        await _supabase
            .from('devices')
            .update(updatedDevice.toJson())
            .eq('id', device.id);

        setState(() {
          final index = _devices.indexWhere((d) => d.id == device.id);
          if (index != -1) {
            _devices[index] = updatedDevice;
          }
        });
      } catch (e) {
        _showError('Erreur lors de la modification de l\'appareil');
      }
    }
  }

  Future<void> _deleteDevice(DeviceModel device) async {
    try {
      await _supabase.from('devices').delete().eq('id', device.id);

      setState(() {
        _devices.removeWhere((d) => d.id == device.id);
      });
    } catch (e) {
      _showError('Erreur lors de la suppression de l\'appareil');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _loadDevices();
    _mqttService.initialize();

    // Animation d'entrée
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() {
        _isExpanded = true;
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: AnimatedPadding(
          padding: EdgeInsets.all(_isExpanded ? 16.0 : 0.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutQuint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CommonHeader(title: 'Paramètres'),
              const SizedBox(height: 16),

              // Theme Selector
              _buildThemeSelector(themeProvider),
              const SizedBox(height: 24),

              // MQTT Status Indicator
              _buildMqttStatusIndicator(),
              const SizedBox(height: 24),

              // Devices Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mes appareils',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Hero(
                    tag: 'add_device_button',
                    child: ElevatedButton.icon(
                      onPressed: _addDevice,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        elevation: 4,
                        shadowColor: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.4),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Device List
              Expanded(
                child:
                    _isLoading
                        ? Center(
                          child: Lottie.asset(
                            'assets/animations/loading.json',
                            width: 600,
                            height: 600,
                          ),
                        )
                        : _devices.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Lottie.asset(
                                'assets/animations/empty_devices.json',
                                width: 180,
                                height: 180,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Aucun appareil trouvé',
                                style: Theme.of(
                                  context,
                                ).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.7),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ajoutez des appareils pour commencer',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        )
                        : AnimatedList(
                          initialItemCount: _devices.length,
                          itemBuilder: (context, index, animation) {
                            final device = _devices[index];
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(1, 0),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutQuint,
                                ),
                              ),
                              child: FadeTransition(
                                opacity: animation,
                                child: _buildDeviceCard(device),
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSelector(ThemeProvider themeProvider) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thème', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  themeProvider.isDarkMode ? 'Mode sombre' : 'Mode clair',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: themeProvider.isDarkMode,
            onChanged: (value) {
              themeProvider.toggleTheme();
            },
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(DeviceModel device) {
    return Dismissible(
      key: Key(device.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Confirmer la suppression'),
                content: Text(
                  'Êtes-vous sûr de vouloir supprimer "${device.name}" ?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Annuler'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Supprimer'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
        );
      },
      onDismissed: (direction) {
        _deleteDevice(device);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shadowColor: Theme.of(context).colorScheme.shadow.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getDeviceIcon(device.location),
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),
          title: Text(
            device.name,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Emplacement: ${device.location}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editDevice(device),
                tooltip: 'Modifier',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteDevice(device),
                tooltip: 'Supprimer',
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getDeviceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'light':
        return Icons.lightbulb;
      case 'tv':
        return Icons.tv;
      case 'ac':
        return Icons.ac_unit;
      case 'fridge':
        return Icons.kitchen;
      case 'heater':
        return Icons.whatshot;
      default:
        return Icons.devices;
    }
  }

  Widget _buildMqttStatusIndicator() {
    return StreamBuilder<MqttConnectionState>(
      stream: _mqttService.connectionStateStream,
      builder: (context, snapshot) {
        final connectionState =
            snapshot.data ?? MqttConnectionState.disconnected;

        Color statusColor;
        String statusText;
        String lottieAsset;

        switch (connectionState) {
          case MqttConnectionState.connected:
            statusColor = Colors.green;
            statusText = 'Connecté';
            lottieAsset = 'assets/animations/connected.json';
            _animationController.stop();
            break;
          case MqttConnectionState.connecting:
            statusColor = Colors.orange;
            statusText = 'Connexion en cours...';
            lottieAsset = 'assets/animations/disconnected.json';
            if (!_animationController.isAnimating) {
              _animationController.repeat();
            }
            break;
          case MqttConnectionState.disconnected:
            statusColor = Colors.red;
            statusText = 'Déconnecté';
            lottieAsset = 'assets/animations/disconnected.json';
            _animationController.stop();
            break;
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: Lottie.asset(lottieAsset, fit: BoxFit.contain),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'État du broker MQTT',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (connectionState == MqttConnectionState.disconnected)
                ElevatedButton(
                  onPressed: () => _mqttService.connect(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    elevation: 2,
                    shadowColor: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.3),
                  ),
                  child: const Text('Reconnecter'),
                ),
            ],
          ),
        );
      },
    );
  }
}
