import 'package:aricie/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> theAppIsRunning(WidgetTester tester) async {
  // On teste l'écran de connexion isolément : sa validation est côté client,
  // donc pas besoin de Supabase ni du démarrage complet de l'application.
  // La surface est agrandie pour que le bouton « Se connecter » soit visible
  // sans défilement.
  await tester.binding.setSurfaceSize(const Size(1000, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
  await tester.pumpAndSettle();
}
