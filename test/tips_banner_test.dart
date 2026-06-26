import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aricie/widgets/daily_energy_tip_banner.dart';

IconData _iconFor(String name) => switch (name) {
      'bolt' => Icons.bolt,
      'water' => Icons.water_drop,
      'thermo' => Icons.thermostat,
      'warning' => Icons.warning_amber_rounded,
      _ => Icons.lightbulb_outline,
    };

void main() {
  setUpAll(() async {
    // SharedPreferences mock (requis par Supabase.initialize)
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // Initialise Supabase avec une URL factice pour permettre au widget de booter
    // sans tenter de connexion réelle. Auth.currentUser reste null → widget no-op.
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test-anon-key-not-real',
    );
  });

  group('_iconFor mapping', () {
    test('bolt', () => expect(_iconFor('bolt'), Icons.bolt));
    test('water', () => expect(_iconFor('water'), Icons.water_drop));
    test('thermo', () => expect(_iconFor('thermo'), Icons.thermostat));
    test('warning', () => expect(_iconFor('warning'), Icons.warning_amber_rounded));
    test('default', () => expect(_iconFor('lightbulb'), Icons.lightbulb_outline));
    test('unknown falls back to lightbulb', () => expect(_iconFor('?'), Icons.lightbulb_outline));
  });

  group('DailyEnergyTipBanner rendering', () {
    testWidgets('renders without exceptions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DailyEnergyTipBanner())),
      );
      expect(find.byType(DailyEnergyTipBanner), findsOneWidget);
    });
  });
}
