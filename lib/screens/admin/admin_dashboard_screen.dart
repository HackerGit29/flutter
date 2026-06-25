import 'package:flutter/material.dart';
import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/screens/update/update_screen.dart';
import 'package:aricie/services/update_service.dart';
import 'package:aricie/theme/app_theme.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:aricie/domain/usecases/admin/get_all_users.dart';
import 'package:aricie/domain/usecases/admin/get_all_devices.dart';
import 'package:aricie/domain/usecases/admin/get_all_subscriptions.dart';
import 'package:aricie/domain/usecases/admin/get_sync_logs.dart';
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

  List<Box> _boxes = [];
  List<User> _users = [];
  List<Subscription> _subscriptions = [];
  List<SyncLog> _logs = [];
  bool _loadingBoxes = true;
  bool _loadingUsers = true;
  bool _loadingSubscriptions = true;
  bool _loadingLogs = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadBoxes(), _loadUsers(), _loadSubscriptions(), _loadLogs()]);
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
            const Tab(text: 'Synchronisations'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabController, children: [
        _buildBoxesTab(),
        _buildUsersTab(),
        _buildSubscriptionsTab(),
        _buildLogsTab(),
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
}
