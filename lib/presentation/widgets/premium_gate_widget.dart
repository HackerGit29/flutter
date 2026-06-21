import 'package:flutter/material.dart';
import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/domain/usecases/license/is_feature_allowed.dart';

class PremiumGateWidget extends StatelessWidget {
  final String featureName;
  final Widget premiumChild;
  final Widget? fallback;

  const PremiumGateWidget({
    super.key,
    required this.featureName,
    required this.premiumChild,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: IsFeatureAllowed(sl()).call(featureName).then(
        (either) => either.getOrElse(() => false)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 24, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        if (snapshot.data == true) return premiumChild;
        return fallback ?? _defaultFallback(context);
      },
    );
  }

  Widget _defaultFallback(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.lock_outline, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text('Fonctionnalité premium', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/upgrade'),
            child: const Text('Passer en VIP'),
          ),
        ],
      ),
    );
  }
}
