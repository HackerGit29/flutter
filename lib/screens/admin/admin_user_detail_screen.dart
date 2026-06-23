import 'package:flutter/material.dart';
import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/theme/app_theme.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/usecases/admin/suspend_user.dart';
import 'package:aricie/domain/usecases/admin/activate_user.dart';
import 'package:aricie/domain/usecases/admin/assign_role.dart';
import 'package:aricie/domain/usecases/admin/get_all_devices.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final User user;
  const AdminUserDetailScreen({super.key, required this.user});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  List<Box> _userBoxes = [];
  bool _loadingBoxes = true;

  @override
  void initState() {
    super.initState();
    _loadBoxes();
  }

  Future<void> _loadBoxes() async {
    setState(() => _loadingBoxes = true);
    final result = await GetAllDevices(sl(), sl()).call();
    result.fold(
      (_) {},
      (all) => _userBoxes = all.where((b) => b.userId == widget.user.id).toList(),
    );
    if (mounted) setState(() => _loadingBoxes = false);
  }

  Future<void> _toggleSuspend() async {
    final user = widget.user;
    final result = user.isSuspended
        ? await ActivateUser(sl(), sl()).call(user.id)
        : await SuspendUser(sl(), sl()).call(user.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.isLeft() ? 'Erreur' : user.isSuspended ? 'Utilisateur activé' : 'Utilisateur suspendu'),
        backgroundColor: result.isLeft() ? Colors.red : Colors.green,
      ));
    }
  }

  Future<void> _changeRole() async {
    final newRole = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(title: const Text('Changer le rôle'), children: [
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'user'), child: const Text('Utilisateur')),
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'vip'), child: const Text('VIP')),
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'admin'), child: const Text('Admin')),
      ]),
    );
    if (newRole == null) return;

    final result = await AssignRole(sl(), sl()).call(widget.user.id, newRole);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.isLeft() ? 'Erreur' : 'Rôle changé en $newRole'),
        backgroundColor: result.isLeft() ? Colors.red : Colors.green,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Scaffold(
      appBar: AppBar(title: Text(user.email)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    CircleAvatar(child: Text(user.email[0].toUpperCase())),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user.email, style: Theme.of(context).textTheme.titleMedium),
                      Text('${user.role.name} · ${user.status.name}', style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  ]),
                  const Divider(),
                  _infoRow('ID', user.id),
                  _infoRow('Rôle', user.role.name),
                  _infoRow('Statut', user.status.name),
                  _infoRow('Inscrit le', user.createdAt.toIso8601String().substring(0, 19)),
                  _infoRow('Abonnement', user.subscriptionId ?? 'Aucun'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              icon: Icon(user.isSuspended ? Icons.check_circle_outline : Icons.block),
              label: Text(user.isSuspended ? 'Activer' : 'Suspendre'),
              onPressed: _toggleSuspend,
              style: ElevatedButton.styleFrom(
                backgroundColor: user.isSuspended ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton.icon(
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Changer rôle'),
              onPressed: _changeRole,
            )),
          ]),
          const SizedBox(height: 24),
          Text('Boîtiers (${_userBoxes.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_loadingBoxes)
            const Center(child: CircularProgressIndicator())
          else if (_userBoxes.isEmpty)
            const Text('Aucun boîtier assigné')
          else
            ..._userBoxes.map((b) => Card(
              margin: const EdgeInsets.symmetric(vertical: 2),
              child: ListTile(
                dense: true,
                leading: Icon(
                  b.isActive ? Icons.check_circle : b.isBlocked ? Icons.block : Icons.warning,
                  color: b.isActive ? Colors.green : b.isBlocked ? Colors.red : Colors.orange,
                  size: 18,
                ),
                title: Text(b.name, style: const TextStyle(fontSize: 13)),
                subtitle: Text('UID: ${b.uidHardware}', style: const TextStyle(fontSize: 11)),
              ),
            )),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(child: Text(value)),
      ]),
    );
  }
}
