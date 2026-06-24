import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/core/constants.dart';
import 'package:aricie/domain/usecases/devices/get_user_appliances.dart';
import 'package:aricie/domain/usecases/devices/add_device.dart';
import 'package:aricie/domain/usecases/devices/remove_device.dart';
import 'package:aricie/domain/usecases/devices/rename_appliance.dart';
import 'package:aricie/domain/entities/appliance.dart';

import 'package:aricie/screens/update/update_screen.dart';
import 'package:aricie/services/update_service.dart';
import 'package:flutter/material.dart';
import 'package:mqtt5_client/mqtt5_client.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:aricie/theme/app_theme.dart';
import '../../services/mqtt_service.dart';
import '../../widgets/common_header.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  final MqttService _mqttService = MqttService();
  late AnimationController _animationController;
  List<Appliance> _appliances = [];
  bool _isLoading = true;
  bool _isExpanded = false;

  Future<void> _loadAppliances() async {
    setState(() => _isLoading = true);

    final result = await GetUserAppliances(sl()).call();
    result.fold(
      (failure) => _showError('Erreur lors du chargement des appareils'),
      (appliances) {
        setState(() {
          _appliances = appliances;
        });
      },
    );

    setState(() => _isLoading = false);
  }

  Future<void> _loadAndInitializeMQTT() async {
    setState(() => _isLoading = true);

    final result = await GetUserAppliances(sl()).call();
    result.fold(
      (failure) {
        _showError('Erreur lors du chargement des appareils');
        setState(() => _isLoading = false);
      },
      (appliances) {
        setState(() {
          _appliances = appliances;
        });
        
        // Connecter MQTT seulement si des appareils existent
        if (appliances.isNotEmpty) {
          _initializeMQTT(appliances.first.boxUid!);
        }
        
        setState(() => _isLoading = false);
      },
    );
  }

  void _initializeMQTT(String boxUid) {
    _mqttService.initialize(
      boxUid: boxUid,
      mqttToken: AppConstants.flespiAppToken,
    );
  }

  Future<void> _addDevice() async {
    final nameController = TextEditingController();
    String selectedLocation = 'Salon';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Ajouter un boîtier'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom du boîtier', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedLocation,
                decoration: const InputDecoration(labelText: 'Emplacement', border: OutlineInputBorder()),
                items: ['Salon', 'Cuisine', 'Chambre', 'Bureau', 'Autres']
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
                onChanged: (v) => setDialogState(() => selectedLocation = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ajouter')),
          ],
        ),
      ),
    );

    if (result == true) {
      final name = nameController.text.trim();
      if (name.isNotEmpty) {
        final addResult = await AddDevice(sl()).call(name, selectedLocation);
        addResult.fold(
          (failure) => _showError('Erreur lors de l\'ajout du boîtier'),
          (_) => _loadAndInitializeMQTT(),
        );
      }
    }
  }

  Future<void> _renameAppliance(Appliance appliance) async {
    final controller = TextEditingController(text: appliance.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renommer l\'appareil'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nom'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      final result = await RenameAppliance(sl()).call(appliance.id, newName);
      result.fold(
        (failure) => _showError('Erreur lors du renommage'),
        (_) => _loadAppliances(),
      );
    }
  }

  Future<void> _deleteAppliance(Appliance appliance) async {
    final result = await RemoveDevice(sl()).call(appliance.boxId);
    result.fold(
      (failure) => _showError('Erreur lors de la suppression'),
      (_) => _loadAppliances(),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.accentDot,
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

    // Charger les appareils et initialiser MQTT en même temps
    _loadAndInitializeMQTT();

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
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: AnimatedPadding(
          padding: EdgeInsets.all(_isExpanded ? AppSpacing.s4 : 0.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutQuint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CommonHeader(title: 'Paramètres'),
              const SizedBox(height: AppSpacing.s4),
              _buildThemeSelector(themeProvider),
              const SizedBox(height: AppSpacing.s6),
              _buildMqttStatusIndicator(),
              const SizedBox(height: AppSpacing.s4),
              _buildUpdateChecker(),
              const SizedBox(height: AppSpacing.s6),
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
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s4),
              Expanded(
                child: _isLoading
                  ? Center(
                      child: Lottie.asset(
                        'assets/animations/loading.json',
                        width: 600, height: 600,
                      ),
                    )
                  : _appliances.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Lottie.asset(
                              'assets/animations/empty_devices.json',
                              width: 180, height: 180,
                            ),
                            const SizedBox(height: AppSpacing.s4),
                            Text('Aucun appareil trouvé',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    : AnimatedList(
                        initialItemCount: _appliances.length,
                        itemBuilder: (context, index, animation) {
                          final appliance = _appliances[index];
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(1, 0), end: Offset.zero,
                            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuint)),
                            child: FadeTransition(
                              opacity: animation,
                              child: _buildApplianceCard(appliance),
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
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [AppShadows.sm],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: Theme.of(context).colorScheme.primary, size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thème', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  themeProvider.isDarkMode ? 'Mode sombre' : 'Mode clair',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: themeProvider.isDarkMode,
            onChanged: (value) => themeProvider.toggleTheme(),
            activeThumbColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildApplianceCard(Appliance appliance) {
    return Dismissible(
      key: Key(appliance.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s3),
        decoration: BoxDecoration(
          color: AppColors.accentDot,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.s5),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: Text('Supprimer tout le boîtier contenant "${appliance.name}" ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.accentDot),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => _deleteAppliance(appliance),
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.s3),
        elevation: 2,
        shadowColor: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s2),
          leading: Container(
            padding: const EdgeInsets.all(AppSpacing.s2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(_getApplianceIcon(appliance.name), color: Theme.of(context).colorScheme.primary, size: 24),
          ),
          title: Text(appliance.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          subtitle: Text(
            'Relais ${appliance.relayIndex}${appliance.location != null ? ' • ${appliance.location}' : ''}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _renameAppliance(appliance),
                tooltip: 'Renommer',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteAppliance(appliance),
                tooltip: 'Supprimer',
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getApplianceIcon(String name) {
    switch (name.toLowerCase()) {
      case 'light': return Icons.lightbulb;
      case 'tv': return Icons.tv;
      case 'ac': return Icons.ac_unit;
      case 'fridge': return Icons.kitchen;
      case 'heater': return Icons.whatshot;
      default: return Icons.devices;
    }
  }

  bool _updateChecking = false;

  Future<void> _checkForUpdates() async {
    setState(() => _updateChecking = true);
    final info = await UpdateService.instance.checkForUpdate();
    if (!mounted) return;
    setState(() => _updateChecking = false);
    if (info.updateAvailable) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => UpdateScreen(updateInfo: info),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Aucune mise à jour disponible'),
          backgroundColor: AppColors.accentMint,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildUpdateChecker() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [AppShadows.sm],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: _updateChecking ? null : _checkForUpdates,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: _updateChecking
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : Icon(Icons.system_update_alt,
                      color: Theme.of(context).colorScheme.primary, size: 24),
            ),
            const SizedBox(width: AppSpacing.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mise à jour',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    'Vérifier les mises à jour de l\'application',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildMqttStatusIndicator() {
    // Pas d'appareils : on masque le bouton, pas de notification
    if (_appliances.isEmpty) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [AppShadows.sm],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 50, height: 50,
              child: Lottie.asset('assets/animations/disconnected.json', fit: BoxFit.contain),
            ),
            const SizedBox(width: AppSpacing.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('État du broker MQTT', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    'Aucun appareil configuré',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Sinon : afficher l'etat reel du broker
    return StreamBuilder<MqttConnectionState>(
      stream: _mqttService.connectionStateStream,
      builder: (context, snapshot) {
        final connectionState = snapshot.data ?? MqttConnectionState.disconnected;
        Color statusColor;
        String statusText;
        String lottieAsset;

        switch (connectionState) {
          case MqttConnectionState.connected:
            statusColor = AppColors.accentMint;
            statusText = 'Connecté';
            lottieAsset = 'assets/animations/connected.json';
            _animationController.stop();
            break;
          case MqttConnectionState.connecting:
            statusColor = AppColors.accentCoral;
            statusText = 'Connexion en cours...';
            lottieAsset = 'assets/animations/disconnected.json';
            if (!_animationController.isAnimating) _animationController.repeat();
            break;
          case MqttConnectionState.disconnected:
            statusColor = AppColors.accentDot;
            statusText = 'Déconnecté';
            lottieAsset = 'assets/animations/disconnected.json';
            _animationController.stop();
            break;
          default:
            statusColor = AppColors.accentDot;
            statusText = 'Inconnu';
            lottieAsset = 'assets/animations/disconnected.json';
            _animationController.stop();
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [AppShadows.sm],
          ),
          child: Row(
            children: [
              SizedBox(width: 50, height: 50, child: Lottie.asset(lottieAsset, fit: BoxFit.contain)),
              const SizedBox(width: AppSpacing.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('État du broker MQTT', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.s1),
                    Text(statusText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: statusColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (connectionState == MqttConnectionState.disconnected && _appliances.isNotEmpty)
                ElevatedButton(
                  onPressed: () => _initializeMQTT(_appliances.first.boxUid!),
                  child: const Text('Reconnecter'),
                ),
            ],
          ),
        );
      },
    );
  }
}
