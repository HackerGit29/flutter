import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:aricie/screens/profile/change_password_screen.dart';

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

  Widget wrap() => const MaterialApp(home: ChangePasswordScreen());

  group('ChangePasswordScreen', () {
    testWidgets('validates all three fields are required', (tester) async {
      await tester.pumpWidget(wrap());

      await tester.tap(find.widgetWithText(ElevatedButton, 'Valider'));
      await tester.pump();

      expect(find.text('Veuillez entrer votre mot de passe actuel'), findsOneWidget);
      expect(find.text('Veuillez entrer un nouveau mot de passe'), findsOneWidget);
    });

    testWidgets('rejects a new password shorter than 6 characters', (tester) async {
      await tester.pumpWidget(wrap());

      await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe actuel'), 'old123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Nouveau mot de passe'), 'abc');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Valider'));
      await tester.pump();

      expect(find.text('Au moins 6 caractères'), findsOneWidget);
    });

    testWidgets('rejects a new password equal to the current one', (tester) async {
      await tester.pumpWidget(wrap());

      await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe actuel'), 'same123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Nouveau mot de passe'), 'same123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Valider'));
      await tester.pump();

      expect(find.text('Le nouveau mot de passe doit être différent'), findsOneWidget);
    });

    testWidgets('rejects a confirmation that does not match', (tester) async {
      await tester.pumpWidget(wrap());

      await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe actuel'), 'old123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Nouveau mot de passe'), 'newpass1');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmer le nouveau mot de passe'), 'newpass2');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Valider'));
      await tester.pump();

      expect(find.text('Les mots de passe ne correspondent pas'), findsOneWidget);
    });

    testWidgets('submits and pops on success', (tester) async {
      await tester.pumpWidget(wrap());

      await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe actuel'), 'old123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Nouveau mot de passe'), 'newpass1');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmer le nouveau mot de passe'), 'newpass1');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Valider'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Mot de passe modifié avec succès.'), findsOneWidget);
    });

    testWidgets('shows the failure message returned by the repository', (tester) async {
      authRepo.failOperations = true;
      await tester.pumpWidget(wrap());

      await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe actuel'), 'old123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Nouveau mot de passe'), 'newpass1');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmer le nouveau mot de passe'), 'newpass1');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Valider'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Mot de passe incorrect'), findsOneWidget);
    });

    testWidgets('toggling visibility switches the button label', (tester) async {
      await tester.pumpWidget(wrap());

      expect(find.text('Afficher'), findsOneWidget);

      await tester.tap(find.text('Afficher'));
      await tester.pump();

      expect(find.text('Masquer'), findsOneWidget);
    });
  });
}
