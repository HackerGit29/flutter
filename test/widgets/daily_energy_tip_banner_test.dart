import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aricie/theme/app_theme.dart';
import 'package:aricie/widgets/daily_energy_tip_banner.dart';
import 'package:aricie/services/tips_realtime_service.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://placeholder.supabase.co',
      anonKey: 'placeholder-anon-key',
    );
  });

  group('tipIconFor', () {
    test('mappe les codes connus vers la bonne icône', () {
      expect(tipIconFor('bolt'), Icons.bolt);
      expect(tipIconFor('water'), Icons.water_drop_outlined);
      expect(tipIconFor('thermo'), Icons.thermostat);
      expect(tipIconFor('warning'), Icons.warning_amber_rounded);
      expect(tipIconFor('lightbulb'), Icons.lightbulb_outline);
    });

    test('retombe sur lightbulb pour un code inconnu', () {
      expect(tipIconFor('inconnu'), Icons.lightbulb_outline);
      expect(tipIconFor(''), Icons.lightbulb_outline);
    });
  });

  group('tipColorFor', () {
    test('mappe la sévérité vers la bonne couleur', () {
      expect(tipColorFor('critical'), AppColors.accentDot);
      expect(tipColorFor('warning'), AppColors.accentGold);
      expect(tipColorFor('info'), AppColors.accentMint);
    });

    test('retombe sur info (mint) pour une sévérité inconnue', () {
      expect(tipColorFor('autre'), AppColors.accentMint);
    });
  });

  group('DailyEnergyTipBanner Widget', () {
    Widget buildTestableWidget(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: child,
        ),
      );
    }

    testWidgets('renders empty space initially when no tip is loaded', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const DailyEnergyTipBanner()));
      await tester.pump();

      expect(find.byType(InkWell), findsNothing);
    });

  });
}
