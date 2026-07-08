// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/the_app_is_running.dart';
import './step/i_tap_text.dart';
import './step/i_see_text.dart';
import './step/i_enter_into_input_field.dart';
import './step/i_wait.dart';

void main() {
  group('''Authentification''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsRunning(tester);
    }

    testWidgets(
        '''Soumettre le formulaire de connexion vide affiche une erreur''',
        (tester) async {
      await bddSetUp(tester);
      await iTapText(tester, 'Se connecter');
      await iSeeText(tester, 'Veuillez entrer votre email');
    });
    testWidgets('''Un email au format invalide affiche une erreur''',
        (tester) async {
      await bddSetUp(tester);
      await iEnterIntoInputField(tester, 'pas-un-email', 0);
      await iTapText(tester, 'Se connecter');
      await iSeeText(tester, 'Veuillez entrer un email valide');
    });
    testWidgets('''Un mot de passe manquant affiche une erreur''',
        (tester) async {
      await bddSetUp(tester);
      await iEnterIntoInputField(tester, 'utilisateur@exemple.com', 0);
      await iTapText(tester, 'Se connecter');
      await iSeeText(tester, 'Veuillez entrer votre mot de passe');
    });
    testWidgets('''Depuis le login, accéder à l'écran d'inscription''',
        (tester) async {
      await bddSetUp(tester);
      await iTapText(tester, "S'inscrire");
      await iWait(tester);
      await iSeeText(tester, 'Créer un compte');
    });
    testWidgets('''Ouvrir la fenêtre de mot de passe oublié''', (tester) async {
      await bddSetUp(tester);
      await iTapText(tester, 'Mot de passe oublié?');
      await iWait(tester);
      await iSeeText(tester, 'Envoyer');
    });
  });
}
