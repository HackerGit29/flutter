import 'package:aricie/screens/auth/reset_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> theResetPasswordScreenIsOpen(WidgetTester tester) async {
  // On teste l'écran de saisie du nouveau mot de passe isolément : ses
  // validateurs (code, longueur, correspondance) sont côté client et
  // s'exécutent avant tout appel au backend. La surface est agrandie pour que
  // le bouton de validation soit visible sans défilement.
  await tester.binding.setSurfaceSize(const Size(1000, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    const MaterialApp(
      home: ResetPasswordScreen(email: 'utilisateur@exemple.com'),
    ),
  );
  await tester.pumpAndSettle();
}
