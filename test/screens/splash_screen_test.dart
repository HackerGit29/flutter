import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aricie/providers/subscription_provider.dart';
import 'package:aricie/screens/onboarding_screen.dart';
import 'package:aricie/screens/splash_screen.dart';
import 'package:aricie/theme/app_theme.dart';

import '../helpers/supabase_test_helper.dart';

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

  Widget wrap(Widget child) => ChangeNotifierProvider(
        create: (_) => SubscriptionProvider(),
        child: MaterialApp(theme: AppTheme.lightTheme, home: child),
      );

  Future<void> pumpThroughNavigation(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('SplashScreen', () {
    testWidgets('renders logo and tagline immediately', (tester) async {
      await tester.pumpWidget(wrap(const SplashScreen()));

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Gérez votre énergie intelligemment'), findsOneWidget);

      await pumpThroughNavigation(tester);
    });

    testWidgets('navigates to OnboardingScreen when no session exists', (tester) async {
      await tester.pumpWidget(wrap(const SplashScreen()));

      await pumpThroughNavigation(tester);

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });
  });
}