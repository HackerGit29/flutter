import 'dart:async';

import 'package:aricie/services/mqtt_service.dart';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/device_model.dart';
import '../../services/notification_service.dart';
import '../../widgets/common_header.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _notificationService = NotificationService();
  final _mqttService = MqttService(); // Ajout du service MQTT
  List<DeviceModel> _devices = [];
  bool _isLoading = true;
  late TabController _tabController;
  
  // Map pour stocker l'état des appareils
  final Map<String, bool> _deviceStates = {};
  
  // Abonnements aux streams
  List<StreamSubscription> _subscriptions = [];
  final List<String> _categories = [
    'Tous',
    'Salon',
    'Cuisine',
    'Chambre',
    'Autres',
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
    
    // Initialiser le service MQTT avant de charger les appareils
    _initializeMqtt();
    _loadDevices();
  }

  Future<void> _initializeMqtt() async {
    print('Initialisation du service MQTT...');
    await _mqttService.initialize();
    
    print('Vérification de l\'état de connexion MQTT...');
    bool isConnected = await _checkMqttConnection();
    if (!isConnected) {
      print('Échec de connexion au broker MQTT');
      // Afficher un message d'erreur à l'utilisateur
      
    } else {
      print('✅ Connecté au broker MQTT');
    }
    
    // Initialiser les états avec les valeurs actuelles du service MQTT
    print('📱 États initiaux des appareils:');
    print('Appareil 1: ${_mqttService.deviceStatus1}');
    print('Appareil 2: ${_mqttService.deviceStatus2}');
    print('Appareil 3: ${_mqttService.deviceStatus3}');
    
    setState(() {
      _deviceStates['1'] = _mqttService.deviceStatus1.toLowerCase() == 'on';
      _deviceStates['2'] = _mqttService.deviceStatus2.toLowerCase() == 'on';
      _deviceStates['3'] = _mqttService.deviceStatus3.toLowerCase() == 'on';
    });
    
    // S'abonner aux streams de statut des appareils
    _subscriptions.add(
      _mqttService.deviceStatusStream1.listen((status) {
        print('📱 Mise à jour statut appareil 1: $status');
        setState(() {
          _deviceStates['1'] = status.toLowerCase() == 'on';
        });
      })
    );
    
    _subscriptions.add(
      _mqttService.deviceStatusStream2.listen((status) {
        print('📱 Mise à jour statut appareil 2: $status');
        setState(() {
          _deviceStates['2'] = status.toLowerCase() == 'on';
        });
      })
    );
    
    _subscriptions.add(
      _mqttService.deviceStatusStream3.listen((status) {
        print('📱 Mise à jour statut appareil 3: $status');
        setState(() {
          _deviceStates['3'] = status.toLowerCase() == 'on';
        });
      })
    );
  }

  @override
  void dispose() {
    // Annuler tous les abonnements
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _tabController.dispose();
    super.dispose();
  }

  // Rest of the loading devices method remains the same
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

  // Add device method with improved UI
  Future<void> _addDevice() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController locationController = TextEditingController();
    String selectedLocation = 'Salon';

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text('Ajouter un appareil'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Nom de l\'appareil',
                          hintText: 'Ex: Ventilateur, Télévision...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.devices),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedLocation,
                        decoration: InputDecoration(
                          labelText: 'Emplacement',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.location_on),
                        ),
                        items:
                            [
                                  'Salon',
                                  'Cuisine',
                                  'Chambre',
                                  'Salle de bain',
                                  'Bureau',
                                  'Autres',
                                ]
                                .map(
                                  (location) => DropdownMenuItem(
                                    value: location,
                                    child: Text(location),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedLocation = value!;
                            locationController.text = value;
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
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
      final location = selectedLocation;

      if (name.isNotEmpty) {
        try {
          // Rest of the add device logic remains the same
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
              'is_read': false,
            };

            // Insert alert and fetch the created alert data
            final alertResponse =
                await _supabase
                    .from('alerts')
                    .insert(alertData)
                    .select()
                    .single();

            // Refresh device list
            await _loadDevices();

            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Appareil "$name" ajouté avec succès'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('Error adding device: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Erreur lors de l\'ajout de l\'appareil'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }
      }
    }

    nameController.dispose();
    locationController.dispose();
  }

  // Delete device method remains mostly the same
  Future<void> _deleteDevice(DeviceModel device) async {
    // Rest of the delete device method remains the same
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Confirmer la suppression'),
            content: Text(
              'Êtes-vous sûr de vouloir supprimer "${device.name}" ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );

    // Rest of the delete implementation remains the same
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

          // Insert alert
          await _supabase.from('alerts').insert(alertData);

          // Refresh device list
          await _loadDevices();

          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Appareil "${device.name}" supprimé avec succès'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error deleting device: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Erreur lors de la suppression de l\'appareil',
              ),
            backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
  }

  // Méthode pour obtenir l'ID physique de l'appareil
  int _getPhysicalDeviceId(DeviceModel device) {
    // Utiliser un attribut spécifique pour déterminer l'ID physique
    // Par exemple, extraire un numéro du nom de l'appareil si possible
    if (device.name.toLowerCase().contains('frigo') || 
        device.name.toLowerCase().contains('appareil 1')) {
      return 1;
    } else if (device.name.toLowerCase().contains('ampoule') || 
              device.name.toLowerCase().contains('appareil 2')) {
      return 2;
    } else if (device.name.toLowerCase().contains('ventilateur') || 
              device.name.toLowerCase().contains('appareil 3')) {
      return 3;
    }
    
    // Si aucun pattern spécifique n'est trouvé, utiliser un hash plus stable
    // Utiliser les 4 premiers caractères de l'ID pour plus de stabilité
    String idPrefix = device.id.length >= 4 ? device.id.substring(0, 4) : device.id;
    int hash = 0;
    for (int i = 0; i < idPrefix.length; i++) {
      hash = (hash * 31 + idPrefix.codeUnitAt(i)) % 3;
    }
    return hash + 1; // 1, 2 ou 3
  }

  // Toggle device method
  Future<void> _toggleDevice(DeviceModel device, bool newState) async {
    // Utiliser la nouvelle méthode de mappage
    final deviceId = _getPhysicalDeviceId(device);
    
    print('Envoi de commande: Appareil $deviceId - ${newState ? "on" : "off"}');
    
    // Vérifier l'état de la connexion MQTT avant d'envoyer
    bool isConnected = await _checkMqttConnection();
    if (!isConnected) {
      print('MQTT non connecté - Tentative de reconnexion...');
      await _mqttService.initialize();
      isConnected = await _checkMqttConnection();
      if (!isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de connexion au broker MQTT'),
            backgroundColor: Colors.white,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    }
    
    // Envoyer la commande via MQTT
    await _mqttService.sendControlCommand(newState ? 'on' : 'off', deviceId);
    
    // Mettre à jour l'état local (sera également mis à jour par le stream)
    setState(() {
      _deviceStates[deviceId.toString()] = newState;
    });
    
    // Afficher un message à l'utilisateur
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${newState ? 'Activation' : 'Désactivation'} de ${device.name}...'
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
  
  // Vérifier l'état de la connexion MQTT
  Future<bool> _checkMqttConnection() async {
    Completer<bool> completer = Completer<bool>();
    
    // Écouter l'état de la connexion pendant 2 secondes maximum
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
    
    // Timeout après 2 secondes
    Future.delayed(const Duration(seconds: 2), () {
      subscription?.cancel();
      if (!completer.isCompleted) completer.complete(false);
    });
    
    return completer.future;
  }

  List<DeviceModel> _getFilteredDevices() {
    if (_selectedCategory == 'Tous') {
      return _devices;
    }
    return _devices
        .where((device) => device.location == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredDevices = _getFilteredDevices();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Replace custom header with CommonHeader widget
              CommonHeader(title: 'Mes Appareils'),

              const SizedBox(height: 24),

              // Category tabs
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.7),
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                tabs:
                    _categories.map((category) => Tab(text: category)).toList(),
              ),

              const SizedBox(height: 16),

              // Device count
              Text(
                '${filteredDevices.length} appareil${filteredDevices.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),

              const SizedBox(height: 16),

              // Device grid/list
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : filteredDevices.isEmpty
                        ? _buildEmptyState()
                        : AnimationLimiter(
                          child: GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.85,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                            itemCount: filteredDevices.length,
                            itemBuilder: (context, index) {
                              final device = filteredDevices[index];
                              return AnimationConfiguration.staggeredGrid(
                                position: index,
                                duration: const Duration(milliseconds: 375),
                                columnCount: 2,
                                child: ScaleAnimation(
                                  child: FadeInAnimation(
                                    child: _buildDeviceCard(device),
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceVariant.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.devices_other,
              size: 48,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun appareil trouvé',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _selectedCategory == 'Tous'
                ? 'Ajoutez des appareils pour commencer'
                : 'Aucun appareil dans cette catégorie',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addDevice,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un appareil'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(DeviceModel device) {
    // Utiliser la nouvelle méthode de mappage
    final deviceId = _getPhysicalDeviceId(device);
    
    // Utiliser l'état réel de l'appareil, ou false par défaut
    final bool isActive = _deviceStates[deviceId.toString()] ?? false;
    
    // Simuler une consommation pour la démo
    final String consumption = '${(device.id.hashCode % 100) / 10}W';

    return GestureDetector(
      onTap: () {
        // Ouvrir les détails de l'appareil
        _showDeviceDetails(device);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isActive
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          isActive
                              ? Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.2)
                              : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getDeviceIcon(device.name),
                      color:
                          isActive
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.6),
                      size: 24,
                    ),
                  ),
                  Switch(
                    value: isActive,
                    onChanged: (value) => _toggleDevice(device, value),
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),

            // Device info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        device.location,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isActive
                              ? Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.1)
                              : Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isActive ? 'Actif • $consumption' : 'Inactif',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            isActive
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
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

  void _showDeviceDetails(DeviceModel device) {
    // Utiliser l'état réel de l'appareil au lieu de simuler
    final deviceId = (device.id.hashCode % 3) + 1;
    final bool isActive = _deviceStates[deviceId.toString()] ?? false;
    final String consumption = '${(device.id.hashCode % 100) / 10}W';
    final String dailyUsage = '${(device.id.hashCode % 24) / 10} heures';
    final String monthlyConsumption = '${device.id.hashCode % 50} kWh';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),

          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              isActive
                                  ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.1)
                                  : Theme.of(
                                    context,
                                  ).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _getDeviceIcon(device.name),
                          color:
                              isActive
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.6),
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  device.location,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isActive,
                        onChanged: (value) {
                          _toggleDevice(device, value);
                          Navigator.pop(context);
                        },
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Stats
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statistiques',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildStatCard(
                            'Consommation actuelle',
                            consumption,
                            Icons.bolt,
                            Colors.white,
                          ),
                          const SizedBox(width: 16),
                          _buildStatCard(
                            'Utilisation quotidienne',
                            dailyUsage,
                            Icons.access_time,
                            Colors.white,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildStatCard(
                        'Consommation mensuelle',
                        monthlyConsumption,
                        Icons.calendar_month,
                        Colors.white,
                        fullWidth: true,
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Actions
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Actions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildActionButton(
                            'Programmer',
                            Icons.schedule,
                            Colors.white,
                            () {},
                          ),
                          const SizedBox(width: 16),
                          _buildActionButton(
                            'Historique',
                            Icons.history,
                            Colors.white,
                            () {},
                          ),
                          const SizedBox(width: 16),
                          _buildActionButton(
                            'Supprimer',
                            Icons.delete,
                            Colors.white,
                            () {
                              Navigator.pop(context);
                              _deleteDevice(device);
                            },
                          ),
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

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool fullWidth = false,
  }) {
    return Expanded(
      flex: fullWidth ? 2 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
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
      return Icons.kitchen;
    if (name.contains('lumière') ||
        name.contains('ampoule') ||
        name.contains('lampe'))
      return Icons.lightbulb;
    if (name.contains('chauffage')) return Icons.whatshot;
    if (name.contains('climatiseur') || name.contains('clim'))
      return Icons.ac_unit;
    if (name.contains('lave') || name.contains('machine'))
      return Icons.local_laundry_service;
    if (name.contains('four')) return Icons.microwave;
    return Icons.devices_other;
  }
}
