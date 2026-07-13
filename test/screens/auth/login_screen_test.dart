import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:aricie/providers/subscription_provider.dart';
import 'package:aricie/screens/auth/login_screen.dart';
import 'package:aricie/theme/app_theme.dart';

import '../../helpers/screen_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthRepository authRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    authRepo = FakeAuthRepository();
    sl.registerLazySingleton<AuthRepository>(() => authRepo);
  });

  tearDown(() async {
    await sl.reset();
  });

  // The footer's "Politique de confidentialité • Conditions d'utilisation"
  // Row has no Flexible/Wrap and overflows the default 800x600 test surface,
  // so use a wide viewport to avoid an unrelated pre-existing layout error.
  Future<void> pumpLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => SubscriptionProvider(),
      child: MaterialApp(theme: AppTheme.lightTheme, home: const LoginScreen()),
    ));
  }

  group('LoginScreen', () {
    testWidgets('validates empty email and password', (tester) async {
      await pumpLogin(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Se connecter'));
      await tester.pump();

      expect(find.text('Veuillez entrer votre email'), findsOneWidget);
      expect(find.text('Veuillez entrer votre mot de passe'), findsOneWidget);
    });

    testWidgets('rejects a malformed email', (tester) async {
      await pumpLogin(tester);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Entrez votre adresse email'), 'not-an-email');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Entrez votre mot de passe'), 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Se connecter'));
      await tester.pump();

      expect(find.text('Veuillez entrer un email valide'), findsOneWidget);
    });

    testWidgets('shows the repository failure message on login failure', (tester) async {
      authRepo.failLogin = true;
      await pumpLogin(tester);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Entrez votre adresse email'), 'user@test.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Entrez votre mot de passe'), 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Se connecter'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Identifiants invalides'), findsOneWidget);
    });

    testWidgets('toggling password visibility switches the obscure icon', (tester) async {
      await pumpLogin(tester);

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('forgot password dialog validates the email field', (tester) async {
      await pumpLogin(tester);

      await tester.tap(find.text('Mot de passe oublié?'));
      await tester.pumpAndSettle();

      expect(find.text('Mot de passe oublié'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Envoyer'));
      await tester.pump();

      expect(find.text('Veuillez entrer votre email'), findsOneWidget);
    });
  });
}
