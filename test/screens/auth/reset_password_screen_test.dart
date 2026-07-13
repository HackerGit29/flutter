import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:aricie/screens/auth/reset_password_screen.dart';

import '../../helpers/screen_test_helper.dart';

void main() {
  late FakeAuthRepository authRepo;

  setUp(() {
    authRepo = FakeAuthRepository();
    sl.registerLazySingleton<AuthRepository>(() => authRepo);
  });

  tearDown(() async {
    await sl.reset();
  });

  Widget wrap() =>
      const MaterialApp(home: ResetPasswordScreen(email: 'user@test.com'));

  group('ResetPasswordScreen', () {
    testWidgets('shows the destination email in the instructions', (tester) async {
      await tester.pumpWidget(wrap());

      expect(find.textContaining('user@test.com'), findsOneWidget);
    });

    testWidgets('validates the OTP code is required and 6 digits', (tester) async {
      await tester.pumpWidget(wrap());

      await tester.tap(find.widgetWithText(ElevatedButton, 'Réinitialiser le mot de passe'));
      await tester.pump();

      expect(find.text('Veuillez entrer le code reçu'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Code de vérification'), '123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Réinitialiser le mot de passe'));
      await tester.pump();

      expect(find.text('Le code doit comporter 6 chiffres'), findsOneWidget);
    });

    testWidgets('rejects a password shorter than 6 characters', (tester) async {
      await tester.pumpWidget(wrap());

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Code de vérification'), '123456');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nouveau mot de passe'), 'abc');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Réinitialiser le mot de passe'));
      await tester.pump();

      expect(find.text('Au moins 6 caractères'), findsOneWidget);
    });

    testWidgets('rejects a mismatched confirmation', (tester) async {
      await tester.pumpWidget(wrap());

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Code de vérification'), '123456');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nouveau mot de passe'), 'newpass1');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmer le mot de passe'), 'other');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Réinitialiser le mot de passe'));
      await tester.pump();

      expect(find.text('Les mots de passe ne correspondent pas'), findsOneWidget);
    });

    testWidgets('submits successfully and shows a confirmation snackbar', (tester) async {
      await tester.pumpWidget(wrap());

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Code de vérification'), '123456');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nouveau mot de passe'), 'newpass1');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmer le mot de passe'), 'newpass1');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Réinitialiser le mot de passe'));
      // Success also calls Navigator.pop(), which starts a page transition;
      // pumpAndSettle would keep pumping until the SnackBar's own display
      // timer elapses too and dismisses it. Use plain pumps instead.
      await tester.pump();
      await tester.pump();

      expect(find.text('Mot de passe réinitialisé. Vous pouvez vous connecter.'), findsOneWidget);
    });

    testWidgets('shows the failure message when confirmation fails', (tester) async {
      authRepo.failOperations = true;
      await tester.pumpWidget(wrap());

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Code de vérification'), '123456');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nouveau mot de passe'), 'newpass1');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmer le mot de passe'), 'newpass1');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Réinitialiser le mot de passe'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Erreur'), findsOneWidget);
    });

    testWidgets('toggling password visibility icon does not throw', (tester) async {
      await tester.pumpWidget(wrap());

      await tester.tap(find.byIcon(Icons.visibility_outlined).first);
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsWidgets);
    });
  });
}
