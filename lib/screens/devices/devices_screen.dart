import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/device_model.dart';
import '../../services/notification_service.dart';
import '../../widgets/common_header.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final _supabase = Supabase.instance.client;
  final _notificationService = NotificationService();
  List<DeviceModel> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
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
          _devices =
              (response as List)
                  .map((data) => DeviceModel.fromJson(data))
                  .toList();
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
    final TextEditingController nameController = TextEditingController();
    final TextEditingController locationController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Ajouter un appareil'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom de l\'appareil',
                    hintText: 'Ex: Ventilateur, Télévision...',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Emplacement',
                    hintText: 'Ex: Salon, Cuisine...',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Ajouter'),
              ),
            ],
          ),
    );

    if (result == true && mounted) {
      final name = nameController.text.trim();
      final location = locationController.text.trim();

      if (name.isNotEmpty && location.isNotEmpty) {
        try {
          final user = _supabase.auth.currentUser;
          if (user != null) {
            // Add device to database
            final deviceData = {
              'name': name,
              'location': location,
              'user_id': user.id,
            };

            final response =
                await _supabase
                    .from('devices')
                    .insert(deviceData)
                    .select()
                    .single();

            // Create alert for new device
            final alertData = {
              'title': 'Nouvel appareil ajouté',
              'description': 'L\'appareil "$name" a été ajouté avec succès.',
              'severity': 'info',
              'user_id': user.id,
              'is_read': false, // Make sure the notification starts as unread
            };

            // Insert alert and fetch the created alert data
            final alertResponse = await _supabase
                .from('alerts')
                .insert(alertData)
                .select()
                .single();


              // Trigger notification service to refresh
            await _supabase.from('alerts').insert(alertData);

            // Refresh device list
            await _loadDevices();

            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Appareil "$name" ajouté avec succès')),
              );
            }
          }
        } catch (e) {
          debugPrint('Error adding device: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Erreur lors de l\'ajout de l\'appareil'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }

    nameController.dispose();
    locationController.dispose();
  }

  Future<void> _deleteDevice(DeviceModel device) async {
    final confirmed = await showDialog<bool>(
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

    if (confirmed == true && mounted) {
      try {
        final user = _supabase.auth.currentUser;
        if (user != null) {
          // Delete device from database
          await _supabase.from('devices').delete().eq('id', device.id);

          // Create alert for device deletion
          final alertData = {
            'title': 'Appareil supprimé',
            'description': 'L\'appareil "${device.name}" a été supprimé.',
            'severity': 'warning',
            'user_id': user.id,
            'is_read': false,
          };

           // Insert alert and fetch the created alert data
          final alertResponse = await _supabase
              .from('alerts')
              .insert(alertData)
              .select()
              .single();

          await _supabase.from('alerts').insert(alertData);

          // Refresh device list
          await _loadDevices();

          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Appareil "${device.name}" supprimé avec succès'),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error deleting device: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur lors de la suppression de l\'appareil'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleDevice(DeviceModel device, bool newState) async {
    // In a real application, you would update the device state in the database
    // and possibly communicate with the actual IoT device
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${newState ? 'Activation' : 'Désactivation'} de ${device.name}...',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CommonHeader(title: 'Gestion des appareils'),
            const SizedBox(height: 16),

            // Add device button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _addDevice,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un appareil'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Device list
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _devices.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.devices_other,
                              size: 64,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun appareil trouvé',
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.5),
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
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (direction) async {
                              return await showDialog<bool>(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text(
                                        'Confirmer la suppression',
                                      ),
                                      content: Text(
                                        'Êtes-vous sûr de vouloir supprimer "${device.name}" ?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.of(
                                                context,
                                              ).pop(false),
                                          child: const Text('Annuler'),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () => Navigator.of(
                                                context,
                                              ).pop(true),
                                          child: const Text('Supprimer'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                              );
                            },
                            onDismissed: (direction) {
                              _deleteDevice(device);
                            },
                            child: DeviceCard(
                              name: device.name,
                              location: device.location,
                              isActive:
                                  false, // You would get this from your database or IoT service
                              consumption:
                                  '0W', // You would get this from your database or IoT service
                              icon: _getDeviceIcon(device.name),
                              onToggle: (value) => _toggleDevice(device, value),
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

  IconData _getDeviceIcon(String deviceName) {
    final name = deviceName.toLowerCase();
    if (name.contains('ventilateur')) return Icons.air;
    if (name.contains('télévision') ||
        name.contains('television') ||
        name.contains('tv'))
      return Icons.tv;
    if (name.contains('frigo') ||
        name.contains('congélateur') ||
        name.contains('congelateur'))
      return Icons.ac_unit;
    if (name.contains('lumière') ||
        name.contains('ampoule') ||
        name.contains('lampe'))
      return Icons.lightbulb;
    if (name.contains('chauffage')) return Icons.whatshot;
    if (name.contains('climatiseur') || name.contains('clim'))
      return Icons.ac_unit;
    return Icons.devices_other;
  }
}

// Device Card Widget
class DeviceCard extends StatelessWidget {
  final String name;
  final String location;
  final bool isActive;
  final String consumption;
  final IconData icon;
  final Function(bool)? onToggle;

  const DeviceCard({
    super.key,
    required this.name,
    required this.location,
    required this.isActive,
    required this.consumption,
    required this.icon,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    isActive
                        ? Theme.of(context).colorScheme.primary.withAlpha(25)
                        : Theme.of(context).colorScheme.surface.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color:
                    isActive
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(128),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    'Emplacement: $location',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Consommation: $consumption',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Switch(value: isActive, onChanged: onToggle),
          ],
        ),
      ),
    );
  }
}
