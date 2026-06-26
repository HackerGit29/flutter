import 'package:flutter_test/flutter_test.dart';

/// Tests miroir des fonctions Edge Function. Les implémentations Dart sont
/// des copies fidèles (smoke test local — la vérité reste l'Edge Function).
bool _matchesCritical(String name) {
  const critical = [
    'chauffe-eau', 'chauffe eau', 'climatiseur', 'clim',
    'four', 'cuisinière', 'cuisiniere',
  ];
  final lower = name.toLowerCase();
  return critical.any(lower.contains);
}

bool _isReadOnly(String name) => name.startsWith('get_');

List<String> _filterToolsForSubscription(
  List<String> tools,
  String? subscriptionType,
) {
  if (subscriptionType == 'vip') return tools;
  return tools.where(_isReadOnly).toList();
}

void main() {
  group('evaluateCriticality (mirror)', () {
    test('chauffe-eau est critique', () {
      expect(_matchesCritical('chauffe-eau'), isTrue);
    });

    test('Climatiseur salon est critique (casse + accent)', () {
      expect(_matchesCritical('Climatiseur Salon'), isTrue);
    });

    test('lampe du salon n\'est pas critique', () {
      expect(_matchesCritical('lampe du salon'), isFalse);
    });

    test('four matche', () {
      expect(_matchesCritical('Four'), isTrue);
    });
  });

  group('isReadOnlyTool (mirror)', () {
    test('get_* sont read-only', () {
      expect(_isReadOnly('get_realtime_consumption'), isTrue);
      expect(_isReadOnly('get_live_consumption'), isTrue);
      expect(_isReadOnly('get_total_consumption'), isTrue);
    });

    test('turn_* ne sont pas read-only', () {
      expect(_isReadOnly('turn_on_appliance'), isFalse);
      expect(_isReadOnly('turn_off_appliance'), isFalse);
    });
  });

  group('filterToolsForSubscription (mirror)', () {
    final allTools = [
      'turn_on_appliance',
      'turn_off_appliance',
      'get_realtime_consumption',
      'get_device_status',
      'get_energy_history',
      'get_live_consumption',
      'get_total_consumption',
    ];

    test('free = read-only only', () {
      final filtered = _filterToolsForSubscription(allTools, 'free');
      expect(filtered, [
        'get_realtime_consumption',
        'get_device_status',
        'get_energy_history',
        'get_live_consumption',
        'get_total_consumption',
      ]);
    });

    test('null subscription = read-only only (safe default)', () {
      final filtered = _filterToolsForSubscription(allTools, null);
      expect(filtered.length, 5);
      expect(filtered.any((t) => t.startsWith('turn_')), isFalse);
    });

    test('vip = tous les tools', () {
      final filtered = _filterToolsForSubscription(allTools, 'vip');
      expect(filtered.length, allTools.length);
    });

    test('downgrade free -> free après vip (pas de cache)', () {
      // Premier appel : vip
      final vip = _filterToolsForSubscription(allTools, 'vip');
      expect(vip.length, allTools.length);
      // Downgrade : free
      final free = _filterToolsForSubscription(allTools, 'free');
      expect(free.length, 5);
    });
  });
}
