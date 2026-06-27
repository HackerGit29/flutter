import 'package:flutter/material.dart';
import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/screens/update/update_screen.dart';
import 'package:aricie/services/update_service.dart';
import 'package:aricie/theme/app_theme.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:aricie/domain/entities/admin_action.dart';
import 'package:aricie/domain/usecases/auth/get_current_user.dart';
import 'package:aricie/domain/usecases/admin/get_all_users.dart';
import 'package:aricie/domain/usecases/admin/get_all_devices.dart';
import 'package:aricie/domain/usecases/admin/get_all_subscriptions.dart';
import 'package:aricie/domain/usecases/admin/get_sync_logs.dart';
import 'package:aricie/domain/usecases/admin/get_admin_actions.dart';
import 'package:aricie/domain/usecases/admin/get_device_commands.dart';
import 'package:aricie/domain/usecases/admin/create_box_for_user.dart';
import 'package:aricie/domain/usecases/admin/create_appliances_for_box.dart';
import 'admin_box_detail_screen.dart';
import 'admin_subscription_detail_screen.dart';
import 'admin_user_detail_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isAdmin = false;

  List<Box> _boxes = [];
  List<User> _users = [];
  List<Subscription> _subscriptions = [];
  List<SyncLog> _logs = [];
  List<AdminAction> _adminActions = [];
  List<Map<String, dynamic>> _deviceCommands = [];
  bool _loadingBoxes = true;
  bool _loadingUsers = true;
  bool _loadingSubscriptions = true;
  bool _loadingLogs = true;
  bool _loadingActions = true;
  bool _loadingCommands = true;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final userResult = await GetCurrentUser(sl()).call();
    final user = userResult.getOrElse(() => null);
    if (user == null || !user.isAdmin) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
      return;
    }
    _isAdmin = true;
    _tabController = TabController(length: 6, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadBoxes(), _loadUsers(), _loadSubscriptions(),
      _loadLogs(), _loadAdminActions(), _loadDeviceCommands(),
    ]);
  }

  Future<void> _loadBoxes() async {
    setState(() => _loadingBoxes = true);
    final result = await GetAllDevices(sl(), sl()).call();
    result.fold(
      (_) {},
      (data) => _boxes = data,
    );
    if (mounted) setState(() => _loadingBoxes = false);
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    final result = await GetAllUsers(sl(), sl()).call();
    result.fold(
      (_) {},
      (data) => _users = data,
    );
    if (mounted) setState(() => _loadingUsers = false);
  }

  Future<void> _loadLogs() async {
    setState(() => _loadingLogs = true);
    final result = await GetSyncLogs(sl(), sl()).call();
    result.fold(
      (_) {},
      (data) => _logs = data,
    );
    if (mounted) setState(() => _loadingLogs = false);
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _loadingSubscriptions = true);
    final result = await GetAllSubscriptions(sl(), sl()).call();
    result.fold(
      (_) {},
      (data) => _subscriptions = data,
    );
    if (mounted) setState(() => _loadingSubscriptions = false);
  }

  Future<void> _loadAdminActions() async {
    setState(() => _loadingActions = true);
    final result = await GetAdminActions(sl(), sl()).call();
    result.fold(
      (_) {},
      (data) => _adminActions = data,
    );
    if (mounted) setState(() => _loadingActions = false);
  }

  Future<void> _loadDeviceCommands() async {
    setState(() => _loadingCommands = true);
    final result = await GetDeviceCommands(sl(), sl()).call();
    result.fold(
      (_) {},
      (data) => _deviceCommands = data,
    );
    if (mounted) setState(() => _loadingCommands = false);
  }

  Future<void> _showCreateBoxDialog() async {
    final uidController = TextEditingController();
    final nameController = TextEditingController();
    String? selectedUserId;
    String selectedLocation = 'Salon';
    String? errorText;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Ajouter un boîtier'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                TextField(
                  controller: uidController,
                  decoration: const InputDecoration(
                    labelText: 'UID matériel *',
                    hintText: 'Ex: ESP32-A1B2C3D4',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom *',
                    hintText: 'Ex: Boîtier cuisine',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedLocation,
                  decoration: const InputDecoration(
                    labelText: 'Emplacement',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Salon', 'Cuisine', 'Chambre', 'Salle de bain', 'Bureau', 'Extérieur', 'Autres']
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                  onChanged: (v) => setDialogState(() => selectedLocation = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedUserId,
                  decoration: const InputDecoration(
                    labelText: 'Propriétaire *',
                    border: OutlineInputBorder(),
                  ),
                  items: _users.map((u) => DropdownMenuItem(
                    value: u.id,
                    child: Text(u.email),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedUserId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (uidController.text.trim().length <= 8) {
                  setDialogState(() => errorText = 'L\'UID matériel doit faire plus de 8 caractères');
                } else if (nameController.text.trim().isEmpty) {
                  setDialogState(() => errorText = 'Le nom est requis');
                } else if (selectedUserId == null) {
                  setDialogState(() => errorText = 'Sélectionnez un propriétaire');
                } else {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );

    if (created == true && mounted) {
      final uid = uidController.text.trim();
      final name = nameController.text.trim();
      final userId = selectedUserId!;

      final boxResult = await CreateBoxForUser(sl(), sl()).call(
        uidHardware: uid,
        name: name,
        location: selectedLocation,
        userId: userId,
      );
      boxResult.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur: ${failure.message}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        },
        (box) async {
          await CreateAppliancesForBox(sl(), sl()).call(box.id, userId);
          await _loadBoxes();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Boîtier "$name" créé avec 3 appareils'),
              backgroundColor: AppColors.accentMint,
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
      );
    }
  }

  Future<void> _checkUpdate() async {
    final info = await UpdateService.instance.checkForUpdate();
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.system_update_alt),
            tooltip: 'Vérifier les mises à jour',
            onPressed: _checkUpdate,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Boîtiers (${_boxes.length})'),
            Tab(text: 'Utilisateurs (${_users.length})'),
            Tab(text: 'Licences (${_subscriptions.length})'),
            const Tab(text: 'Synchros'),
            Tab(text: 'Actions (${_adminActions.length})'),
            Tab(text: 'Commandes (${_deviceCommands.length})'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
        ? FloatingActionButton(
            onPressed: _showCreateBoxDialog,
            child: const Icon(Icons.add),
          )
        : null,
      body: TabBarView(controller: _tabController, children: [
        _buildBoxesTab(),
        _buildUsersTab(),
        _buildSubscriptionsTab(),
        _buildLogsTab(),
        _buildActionsTab(),
        _buildDeviceCommandsTab(),
      ]),
    );
  }

  Widget _buildBoxesTab() {
    if (_loadingBoxes) return const Center(child: CircularProgressIndicator());
    if (_boxes.isEmpty) return const Center(child: Text('Aucun boîtier'));
    return RefreshIndicator(
      onRefresh: _loadBoxes,
      child: ListView.builder(
        itemCount: _boxes.length,
        itemBuilder: (context, i) {
          final box = _boxes[i];
          final owner = _users.where((u) => u.id == box.userId).firstOrNull;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: Icon(
                box.isActive ? Icons.check_circle : box.isBlocked ? Icons.block : Icons.warning,
                color: box.isActive ? Colors.green : box.isBlocked ? Colors.red : Colors.orange,
              ),
              title: Text(box.name),
              subtitle: Text('UID: ${box.uidHardware}\n${owner?.email ?? box.userId}'),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => AdminBoxDetailScreen(box: box),
              )).then((_) => _loadBoxes()),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUsersTab() {
    if (_loadingUsers) return const Center(child: CircularProgressIndicator());
    if (_users.isEmpty) return const Center(child: Text('Aucun utilisateur'));
    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, i) {
          final u = _users[i];
          final boxCount = _boxes.where((b) => b.userId == u.id).length;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(child: Text(u.email[0].toUpperCase())),
              title: Text(u.email),
              subtitle: Text('Rôle: ${u.role.name} · Statut: ${u.status.name}\n$boxCount boîtier(s)'),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => AdminUserDetailScreen(user: u),
              )).then((_) => _loadUsers()),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogsTab() {
    if (_loadingLogs) return const Center(child: CircularProgressIndicator());
    if (_logs.isEmpty) return const Center(child: Text('Aucune synchronisation'));
    return RefreshIndicator(
      onRefresh: _loadLogs,
      child: ListView.builder(
        itemCount: _logs.length,
        itemBuilder: (context, i) {
          final log = _logs[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: Icon(
                log.status == 'success' ? Icons.sync : Icons.error,
                color: log.status == 'success' ? Colors.green : Colors.red,
              ),
              title: Text('Boîtier: ${log.boxId}'),
              subtitle: Text(
                '${log.status.name} · ${log.timestamp.toIso8601String().substring(0, 19)}',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubscriptionsTab() {
    if (_loadingSubscriptions) return const Center(child: CircularProgressIndicator());
    if (_subscriptions.isEmpty) return const Center(child: Text('Aucune licence'));
    return RefreshIndicator(
      onRefresh: _loadSubscriptions,
      child: ListView.builder(
        itemCount: _subscriptions.length,
        itemBuilder: (context, i) {
          final subscription = _subscriptions[i];
          final owner = _users.where((u) => u.id == subscription.userId).firstOrNull;
          final isValid = subscription.isValid;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: Icon(
                isValid ? Icons.verified : Icons.cancel_outlined,
                color: isValid ? Colors.green : Colors.red,
              ),
              title: Text(owner?.email ?? subscription.userId),
              subtitle: Text(
                'Type: ${subscription.type.name} · ${subscription.isActive ? 'active' : 'inactive'}\n'
                'Renouvellement: ${subscription.autoRenew ? 'oui' : 'non'}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => AdminSubscriptionDetailScreen(
                  subscription: subscription,
                  owner: owner,
                ),
              )).then((_) => _loadSubscriptions()),
            ),
          );
        },
      ),
    );
  }

  String _adminActionLabel(AdminAction a) {
    switch (a.action) {
      case AdminActionType.suspendUser: return 'Suspension utilisateur';
      case AdminActionType.activateUser: return 'Activation utilisateur';
      case AdminActionType.assignRole: return 'Changement rôle';
      case AdminActionType.resetDevice: return 'Réinitialisation boîtier';
      case AdminActionType.forceSync: return 'Sync forcée';
      case AdminActionType.overrideOwnership: return 'Override ownership';
      case AdminActionType.blockDevice: return 'Blocage boîtier';
      case AdminActionType.activateLicense: return 'Activation licence';
      case AdminActionType.revokeLicense: return 'Révocation licence';
      case AdminActionType.resetBox: return 'Réinitialisation boîtier';
      case AdminActionType.assignBox: return 'Assignation boîtier';
    }
  }

  Widget _buildActionsTab() {
    if (_loadingActions) return const Center(child: CircularProgressIndicator());
    if (_adminActions.isEmpty) return const Center(child: Text('Aucune action admin'));
    return RefreshIndicator(
      onRefresh: _loadAdminActions,
      child: ListView.builder(
        itemCount: _adminActions.length,
        itemBuilder: (context, i) {
          final a = _adminActions[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: Icon(
                _actionIcon(a.action),
                color: _actionColor(a.action),
                size: 20,
              ),
              title: Text(_adminActionLabel(a), style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                '${a.targetId.substring(0, 8)}… · ${a.adminId.substring(0, 8)}…\n'
                '${a.timestamp.toIso8601String().substring(0, 19)}',
                style: const TextStyle(fontSize: 11),
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }

  IconData _actionIcon(AdminActionType action) {
    switch (action) {
      case AdminActionType.suspendUser: return Icons.block;
      case AdminActionType.activateUser: return Icons.check_circle_outline;
      case AdminActionType.assignRole: return Icons.swap_horiz;
      case AdminActionType.resetDevice: case AdminActionType.resetBox: return Icons.restart_alt;
      case AdminActionType.forceSync: return Icons.sync;
      case AdminActionType.overrideOwnership: return Icons.admin_panel_settings;
      case AdminActionType.blockDevice: return Icons.cancel;
      case AdminActionType.activateLicense: return Icons.verified;
      case AdminActionType.revokeLicense: return Icons.remove_circle;
      case AdminActionType.assignBox: return Icons.assignment;
    }
  }

  Color _actionColor(AdminActionType action) {
    switch (action) {
      case AdminActionType.suspendUser: case AdminActionType.blockDevice: case AdminActionType.revokeLicense:
        return Colors.red;
      case AdminActionType.activateUser: case AdminActionType.activateLicense:
        return Colors.green;
      case AdminActionType.assignRole: case AdminActionType.assignBox:
        return Colors.blue;
      case AdminActionType.resetDevice: case AdminActionType.resetBox:
        return Colors.orange;
      case AdminActionType.forceSync:
        return Colors.teal;
      case AdminActionType.overrideOwnership:
        return Colors.purple;
    }
  }

  Widget _buildDeviceCommandsTab() {
    if (_loadingCommands) return const Center(child: CircularProgressIndicator());
    if (_deviceCommands.isEmpty) return const Center(child: Text('Aucune commande'));
    return RefreshIndicator(
      onRefresh: _loadDeviceCommands,
      child: ListView.builder(
        itemCount: _deviceCommands.length,
        itemBuilder: (context, i) {
          final cmd = _deviceCommands[i];
          final status = cmd['status'] as String? ?? '';
          final action = cmd['action'] as String? ?? '';
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: Icon(
                action == 'on' ? Icons.power_settings_new : Icons.power_off,
                color: status == 'acknowledged' ? Colors.green
                     : status == 'failed' || status == 'rejected' ? Colors.red
                     : status == 'sent' ? Colors.blue
                     : Colors.orange,
                size: 20,
              ),
              title: Text(
                '${cmd['appliance_name'] ?? 'App #${cmd['relay_index']}'} · ${action == 'on' ? 'ON' : 'OFF'}',
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                '${cmd['box_uid'] ?? ''} · $status\n'
                '${cmd['requested_by'] ?? ''} · ${(cmd['created_at'] as String?)?.substring(0, 19) ?? ''}',
                style: const TextStyle(fontSize: 11),
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}
