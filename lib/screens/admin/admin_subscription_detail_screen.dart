import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/usecases/admin/activate_subscription.dart';
import 'package:aricie/domain/usecases/admin/revoke_subscription.dart';
import 'package:flutter/material.dart';

class AdminSubscriptionDetailScreen extends StatefulWidget {
  final Subscription subscription;
  final User? owner;

  const AdminSubscriptionDetailScreen({
    super.key,
    required this.subscription,
    this.owner,
  });

  @override
  State<AdminSubscriptionDetailScreen> createState() => _AdminSubscriptionDetailScreenState();
}

class _AdminSubscriptionDetailScreenState extends State<AdminSubscriptionDetailScreen> {
  late Subscription _subscription;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.subscription;
  }

  Future<void> _activate() async {
    setState(() => _updating = true);
    final result = await ActivateSubscription(sl(), sl()).call(_subscription.id);
    if (!mounted) return;
    setState(() => _updating = false);
    result.fold(
      (_) => _showMessage('Erreur lors de l\'activation', Colors.red),
      (subscription) {
        setState(() => _subscription = subscription);
        _showMessage('Licence activée', Colors.green);
      },
    );
  }

  Future<void> _revoke() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Révoquer la licence'),
        content: const Text('Révoquer cette licence et désactiver l\'abonnement ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Révoquer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _updating = true);
    final result = await RevokeSubscription(sl(), sl()).call(_subscription.id);
    if (!mounted) return;
    setState(() => _updating = false);
    result.fold(
      (_) => _showMessage('Erreur lors de la révocation', Colors.red),
      (subscription) {
        setState(() => _subscription = subscription);
        _showMessage('Licence révoquée', Colors.green);
      },
    );
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final owner = widget.owner;
    return Scaffold(
      appBar: AppBar(title: const Text('Licence')),
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
                    Icon(
                      _subscription.isValid ? Icons.verified : Icons.cancel_outlined,
                      color: _subscription.isValid ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _subscription.isValid ? 'Valide' : 'Inactive',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ]),
                  const Divider(),
                  _infoRow('Utilisateur', owner?.email ?? _subscription.userId),
                  _infoRow('Type', _subscription.type.name),
                  _infoRow('Active', _subscription.isActive ? 'oui' : 'non'),
                  _infoRow('Auto-renew', _subscription.autoRenew ? 'oui' : 'non'),
                  _infoRow('Début', _subscription.startDate.toIso8601String().substring(0, 19)),
                  _infoRow('Fin', _subscription.endDate?.toIso8601String().substring(0, 19) ?? 'Aucune'),
                  _infoRow('Créée le', _subscription.createdAt.toIso8601String().substring(0, 19)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              icon: _updating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle_outline),
              label: const Text('Activer'),
              onPressed: _updating || _subscription.isActive ? null : _activate,
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton.icon(
              icon: const Icon(Icons.block),
              label: const Text('Révoquer'),
              onPressed: _updating || !_subscription.isActive ? null : _revoke,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            )),
          ]),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(child: Text(value)),
      ]),
    );
  }
}
