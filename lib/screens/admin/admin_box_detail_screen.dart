import 'package:flutter/material.dart';
import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/entities/sync_log.dart';
import 'package:aricie/domain/usecases/admin/reset_device.dart';
import 'package:aricie/domain/usecases/admin/assign_device.dart';
import 'package:aricie/domain/usecases/admin/force_sync.dart';
import 'package:aricie/domain/usecases/admin/get_sync_logs.dart';
import 'package:aricie/domain/usecases/admin/override_ownership.dart';

class AdminBoxDetailScreen extends StatefulWidget {
  final Box box;
  const AdminBoxDetailScreen({super.key, required this.box});

  @override
  State<AdminBoxDetailScreen> createState() => _AdminBoxDetailScreenState();
}

class _AdminBoxDetailScreenState extends State<AdminBoxDetailScreen> {
  List<SyncLog> _logs = [];
  bool _loadingLogs = true;
  bool _resetting = false;
  bool _forcingSync = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loadingLogs = true);
    final result = await GetSyncLogs(sl(), sl()).call(boxId: widget.box.id);
    result.fold(
      (_) {},
      (data) => _logs = data,
    );
    if (mounted) setState(() => _loadingLogs = false);
  }

  Future<void> _resetBox() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Réinitialiser le boîtier'),
        content: Text('Réinitialiser "${widget.box.name}" ?\nUID: ${widget.box.uidHardware}\nLe boîtier sera dissocié de son utilisateur.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Réinitialiser'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red)),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _resetting = true);
    final result = await ResetDevice(sl(), sl()).call(widget.box.id);
    if (mounted) setState(() => _resetting = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.isLeft() ? 'Erreur lors de la réinitialisation' : 'Boîtier réinitialisé'),
      backgroundColor: result.isLeft() ? Colors.red : Colors.green,
    ));
  }

  Future<void> _assignBox() async {
    final userIdController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assigner le boîtier'),
        content: TextField(
          controller: userIdController,
          decoration: const InputDecoration(labelText: 'ID utilisateur', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, userIdController.text.trim()), child: const Text('Assigner')),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;

    final assignResult = await AssignDevice(sl(), sl()).call(widget.box.id, result);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(assignResult.isLeft() ? 'Erreur lors de l\'assignation' : 'Boîtier assigné'),
        backgroundColor: assignResult.isLeft() ? Colors.red : Colors.green,
      ));
    }
  }

  Future<void> _overrideOwnership() async {
    final userIdController = TextEditingController();
    final reasonController = TextEditingController();
    final result = await showDialog<({String userId, String reason})>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Override ownership'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userIdController,
              decoration: const InputDecoration(labelText: 'ID utilisateur cible', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Justification', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, (
              userId: userIdController.text.trim(),
              reason: reasonController.text.trim(),
            )),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (result == null || result.userId.isEmpty || result.reason.isEmpty) return;

    final overrideResult = await OverrideOwnership(sl(), sl()).call(
      widget.box.id,
      result.userId,
      result.reason,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(overrideResult.isLeft() ? 'Erreur lors de l\'override' : 'Ownership modifié'),
        backgroundColor: overrideResult.isLeft() ? Colors.red : Colors.green,
      ));
    }
  }

  Future<void> _forceSync() async {
    setState(() => _forcingSync = true);
    final result = await ForceSync(sl(), sl()).call(widget.box.id);
    if (mounted) setState(() => _forcingSync = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.isLeft() ? 'Erreur lors de la synchronisation' : 'Synchronisation forcée'),
        backgroundColor: result.isLeft() ? Colors.red : Colors.green,
      ));
    }
    if (result.isRight()) await _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.box;
    return Scaffold(
      appBar: AppBar(title: Text(box.name)),
      body: RefreshIndicator(
        onRefresh: _loadLogs,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(box.isActive ? Icons.check_circle : box.isBlocked ? Icons.block : Icons.warning, color: box.isActive ? Colors.green : box.isBlocked ? Colors.red : Colors.orange),
                      const SizedBox(width: 8),
                      Text(box.isActive ? 'Actif' : box.isBlocked ? 'Bloqué' : 'Inactif', style: Theme.of(context).textTheme.titleMedium),
                    ]),
                    const Divider(),
                    _infoRow('UID', box.uidHardware),
                    _infoRow('Utilisateur', box.userId),
                    _infoRow('Emplacement', box.location ?? '—'),
                    _infoRow('Firmware', box.firmwareVersion ?? '—'),
                    _infoRow('Dernière synchro', box.lastSync?.toIso8601String().substring(0, 19) ?? 'Jamais'),
                    _infoRow('Créé le', box.createdAt.toIso8601String().substring(0, 19)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Assigner'),
                onPressed: _assignBox,
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                icon: _resetting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.restart_alt),
                label: const Text('Réinitialiser'),
                onPressed: _resetting ? null : _resetBox,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              )),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                icon: _forcingSync ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync),
                label: const Text('Forcer sync'),
                onPressed: _forcingSync ? null : _forceSync,
              )),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('Override'),
                onPressed: _overrideOwnership,
              )),
            ]),
            const SizedBox(height: 24),
            Text('Historique des synchronisations', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_loadingLogs)
              const Center(child: CircularProgressIndicator())
            else if (_logs.isEmpty)
              const Text('Aucune synchronisation')
            else
              ..._logs.map((log) => Card(
                margin: const EdgeInsets.symmetric(vertical: 2),
                child: ListTile(
                  dense: true,
                  leading: Icon(log.status == 'success' ? Icons.sync : Icons.error, size: 18, color: log.status == 'success' ? Colors.green : Colors.red),
                  title: Text('${log.status.name} · ${log.timestamp.toIso8601String().substring(0, 19)}', style: const TextStyle(fontSize: 13)),
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(child: Text(value)),
      ]),
    );
  }
}
