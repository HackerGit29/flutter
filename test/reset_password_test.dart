// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/the_reset_password_screen_is_open.dart';
import './step/i_tap_text.dart';
import './step/i_see_text.dart';
import './step/i_enter_into_input_field.dart';

void main() {
  group('''Réinitialisation du mot de passe''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theResetPasswordScreenIsOpen(tester);
    }

    testWidgets('''Un code de vérification vide affiche une erreur''',
        (tester) async {
      await bddSetUp(tester);
      await iTapText(tester, 'Réinitialiser le mot de passe');
      await iSeeText(tester, 'Veuillez entrer le code reçu');
    });
    testWidgets('''Un code trop court affiche une erreur''', (tester) async {
      await bddSetUp(tester);
      await iEnterIntoInputField(tester, '123', 0);
      await iTapText(tester, 'Réinitialiser le mot de passe');
      await iSeeText(tester, 'Le code doit comporter 6 chiffres');
    });
    testWidgets('''Un mot de passe vide affiche une erreur''', (tester) async {
      await bddSetUp(tester);
      await iEnterIntoInputField(tester, '123456', 0);
      await iTapText(tester, 'Réinitialiser le mot de passe');
      await iSeeText(tester, 'Veuillez entrer un mot de passe');
    });
    testWidgets('''Un mot de passe trop court affiche une erreur''',
        (tester) async {
      await bddSetUp(tester);
      await iEnterIntoInputField(tester, '123456', 0);
      await iEnterIntoInputField(tester, 'abc', 1);
      await iTapText(tester, 'Réinitialiser le mot de passe');
      await iSeeText(tester, 'Au moins 6 caractères');
    });
    testWidgets('''Une confirmation différente affiche une erreur''',
        (tester) async {
      await bddSetUp(tester);
      await iEnterIntoInputField(tester, '123456', 0);
      await iEnterIntoInputField(tester, 'motdepasse', 1);
      await iEnterIntoInputField(tester, 'different', 2);
      await iTapText(tester, 'Réinitialiser le mot de passe');
      await iSeeText(tester, 'Les mots de passe ne correspondent pas');
    });
  });
}
