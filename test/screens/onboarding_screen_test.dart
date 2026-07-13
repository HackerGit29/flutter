import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/screens/auth/login_screen.dart';
import 'package:aricie/screens/onboarding_screen.dart';
import 'package:aricie/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // OnboardingScreen renders a looping Lottie animation per page plus several
  // flutter_animate `Future.delayed` schedules, so pumpAndSettle never
  // returns. Advance in small fixed steps instead. The default 800x600 test
  // surface is also too short for the page content, so use a phone viewport.
  Future<void> pumpOnboarding(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const OnboardingScreen()),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('OnboardingScreen', () {
    testWidgets('shows the first page with a "Suivant" button', (tester) async {
      await pumpOnboarding(tester);

      expect(find.text('Suivez votre consommation'), findsOneWidget);
      expect(find.text('Suivant'), findsOneWidget);
    });

    testWidgets('swiping through all pages reaches "Commencer"', (tester) async {
      await pumpOnboarding(tester);

      await tester.tap(find.text('Suivant'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Contrôlez vos appareils'), findsOneWidget);

      await tester.tap(find.text('Suivant'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Économisez de l\'énergie'), findsOneWidget);
      expect(find.text('Commencer'), findsOneWidget);
    });

    testWidgets('tapping "Se connecter" navigates to LoginScreen', (tester) async {
      await pumpOnboarding(tester);

      await tester.tap(find.text('Se connecter'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
