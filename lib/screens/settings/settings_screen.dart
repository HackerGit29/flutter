import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/device_model.dart';
import '../../services/mqtt_service.dart';
import '../../widgets/common_header.dart';
import 'device_form_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final MqttService _mqttService = MqttService();
  late AnimationController _animationController;
  List<DeviceModel> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    _loadDevices();
    _mqttService.initialize();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final response = await _supabase
            .from('devices')
            .select()
            .eq('user_id', user.id)
            .order('created_at', ascending: false);

        setState(() {
          _devices = (response as List).map((data) => DeviceModel.fromJson(data)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading devices: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addDevice() async {
    final result = await showDialog<DeviceModel>(
      context: context,
      builder: (context) => const DeviceFormDialog(),
    );

    if (result != null) {
      await _loadDevices();
    }
  }

  Future<void> _editDevice(DeviceModel device) async {
    final result = await showDialog<DeviceModel>(
      context: context,
      builder: (context) => DeviceFormDialog(device: device),
    );

    if (result != null) {
      await _loadDevices();
    }
  }

  Future<void> _deleteDevice(DeviceModel device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Êtes-vous sûr de vouloir supprimer "${device.name}" ?'),
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

    if (confirmed == true) {
      try {
        await _supabase.from('devices').delete().eq('id', device.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${device.name} supprimé avec succès')),
        );
        await _loadDevices();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la suppression de l\'appareil'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            const CommonHeader(title: 'Paramètres'),
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
                ElevatedButton.icon(
                  onPressed: _addDevice,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Device List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _devices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.devices_other,
                                size: 64,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Aucun appareil trouvé',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ajoutez des appareils pour commencer',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                    ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _devices.length,
                          itemBuilder: (context, index) {
                            final device = _devices[index];
                            return Dismissible(
                              key: Key(device.id),
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (direction) async {
                                return await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Confirmer la suppression'),
                                    content: Text('Êtes-vous sûr de vouloir supprimer "${device.name}" ?'),
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
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.devices,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  title: Text(device.name),
                                  subtitle: Text('Emplacement: ${device.location}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () => _editDevice(device),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () => _deleteDevice(device),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMqttStatusIndicator() {
    return StreamBuilder<MqttConnectionState>(
      stream: _mqttService.connectionStateStream,
      builder: (context, snapshot) {
        final connectionState = snapshot.data ?? MqttConnectionState.disconnected;
        
        Color statusColor;
        String statusText;
        IconData statusIcon;
        
        switch (connectionState) {
          case MqttConnectionState.connected:
            statusColor = Colors.green;
            statusText = 'Connecté';
            statusIcon = Icons.cloud_done;
            _animationController.stop();
            break;
          case MqttConnectionState.connecting:
            statusColor = Colors.orange;
            statusText = 'Connexion en cours...';
            statusIcon = Icons.sync;
            if (!_animationController.isAnimating) {
              _animationController.repeat();
            }
            break;
          case MqttConnectionState.disconnected:
            statusColor = Colors.red;
            statusText = 'Déconnecté';
            statusIcon = Icons.cloud_off;
            _animationController.stop();
            break;
        }
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: connectionState == MqttConnectionState.connecting
                        ? _animationController.value * 2 * 3.14159
                        : 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        statusIcon,
                        color: statusColor,
                        size: 24,
                      ),
                    ),
                  );
                },
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