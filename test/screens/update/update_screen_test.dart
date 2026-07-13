import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aricie/screens/update/update_screen.dart';
import 'package:aricie/services/update_service.dart';

import '../../helpers/supabase_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-anon-key',
      httpClient: MockClient((request) async => emptyOk(request)),
      authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.implicit),
    );
  });

  UpdateInfo info({bool forceUpdate = false}) => UpdateInfo(
        updateAvailable: true,
        version: '1.6.0',
        apkUrl: 'https://example.com/app.apk',
        releaseNotes: 'Bug fixes',
        forceUpdate: forceUpdate,
      );

  // The Lottie animation is driven by a repeating AnimationController, so
  // pumpAndSettle never returns; advance a bounded number of frames instead.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('UpdateScreen', () {
    testWidgets('renders the version badge and description', (tester) async {
      await tester.pumpWidget(MaterialApp(home: UpdateScreen(updateInfo: info())));
      await settle(tester);

      expect(find.text('Nouvelle version disponible'), findsOneWidget);
      expect(find.text('v1.6.0'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Télécharger'), findsOneWidget);
    });

    testWidgets('hides the "later" button when the update is forced', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UpdateScreen(updateInfo: info(forceUpdate: true))),
      );
      await settle(tester);

      expect(find.text('Plus tard'), findsNothing);
    });

    testWidgets('shows the "later" button and pops when the update is optional',
        (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => UpdateScreen(updateInfo: info())),
            ),
            child: const Text('open'),
          );
        }),
      ));
      await tester.tap(find.text('open'));
      await settle(tester);

      expect(find.text('Plus tard'), findsOneWidget);

      await tester.ensureVisible(find.text('Plus tard'));
      await tester.tap(find.text('Plus tard'));
      await settle(tester);
      await settle(tester);

      expect(find.byType(UpdateScreen), findsNothing);
    });

    testWidgets('shows a fallback version marker when the version is missing',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: UpdateScreen(updateInfo: UpdateInfo(updateAvailable: true)),
      ));
      await settle(tester);

      expect(find.text('v?'), findsOneWidget);
    });
  });
}
