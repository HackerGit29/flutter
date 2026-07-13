import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/domain/entities/appliance.dart';
import 'package:aricie/domain/repositories/appliance_repository.dart';
import 'package:aricie/screens/devices/devices_screen.dart';
import 'package:aricie/services/mqtt_service.dart';
import 'package:aricie/theme/app_theme.dart';

import '../../helpers/screen_test_helper.dart';

void main() {
  late FakeApplianceRepository applianceRepo;

  setUp(() {
    applianceRepo = FakeApplianceRepository();
    sl.registerLazySingleton<ApplianceRepository>(() => applianceRepo);
    sl.registerLazySingleton<MqttService>(() => MqttService());
  });

  tearDown(() async {
    await sl.reset();
  });

  Widget wrap() =>
      MaterialApp(theme: AppTheme.lightTheme, home: const DevicesScreen());

  group('DevicesScreen', () {
    testWidgets('shows a loading indicator first', (tester) async {
      await tester.pumpWidget(wrap());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders the appliance card once loaded', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text(kScreenAppliance.name), findsOneWidget);
      expect(find.text('1 appareil'), findsOneWidget);
      expect(find.text('Actif'), findsOneWidget);
    });

    testWidgets('shows the empty state when there are no appliances', (tester) async {
      applianceRepo.appliances = [];
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Aucun appareil trouvé'), findsOneWidget);
    });

    testWidgets('filters appliances by category chip', (tester) async {
      final other = kScreenAppliance.copyWith(location: 'Cuisine');
      applianceRepo.appliances = [
        kScreenAppliance,
        Appliance(
          id: 'app-2',
          boxId: 'box-1',
          userId: 'user-1',
          relayIndex: 2,
          name: 'Four',
          location: 'Cuisine',
          createdAt: DateTime(2026, 1, 1),
        ),
      ];
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('2 appareils'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Cuisine'));
      await tester.pumpAndSettle();

      expect(find.text('1 appareil'), findsOneWidget);
      expect(find.text('Four'), findsOneWidget);
      expect(other, isNotNull);
    });

    testWidgets('toggling the switch calls the repository', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      expect(tester.widget<Switch>(switchFinder).value, true);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(switchFinder).value, false);
    });

    testWidgets('tapping a card opens the appliance detail bottom sheet',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text(kScreenAppliance.name));
      await tester.pumpAndSettle();

      expect(find.text('Consommation en temps réel'), findsOneWidget);
      expect(find.text('(en attente du boîtier)'), findsOneWidget);
    });
  });
}
