# Stratégie de tests fonctionnels (BDD / Cucumber) — Aricie

## Objectif

Décrire l'approche de tests fonctionnels automatisés de l'application Aricie,
rédigés en **Gherkin** (langage naturel Given/When/Then) selon une démarche
**BDD (Behavior-Driven Development)**, et exécutés automatiquement.

## Outil retenu

Les scénarios sont écrits dans des fichiers `.feature` et exécutés avec
**`bdd_widget_test`**. Cet outil génère, à partir de chaque `.feature`, un test
widget Flutter classique, lancé via `flutter test`.

Justification du choix : l'outil BDD historique `flutter_gherkin` n'est plus
compatible avec la version de l'environnement (sa dernière version stable repose
sur `flutter_driver` incompatible avec Flutter récent, et ses versions
`integration_test` exigent Dart < 3.0 alors que le projet est en Dart 3).
`bdd_widget_test` est maintenu, compatible Dart 3, et présente un avantage
décisif : les tests s'exécutent **sur la machine de développement, sans
téléphone ni émulateur**, en quelques secondes — donc reproductibles en
intégration continue.

## Organisation des fichiers

```
test/
  auth.feature                  # scénarios Gherkin (rédigés à la main)
  auth_test.dart                # test généré par build_runner (NE PAS éditer)
  step/
    the_app_is_running.dart     # démarrage de l'écran testé (écrit à la main)
    i_tap_text.dart             # steps fournis par bdd_widget_test
    i_see_text.dart
    i_enter_into_input_field.dart
    i_wait.dart
```

- Les fichiers `*_test.dart` sont **régénérés** à chaque modification des
  `.feature` : ne pas les modifier manuellement.
- Les fichiers de `step/` ne sont **pas** régénérés une fois créés : ils sont
  librement modifiables (ex. `the_app_is_running.dart`).

## Comment exécuter les tests

```bash
# 1. (Re)générer les tests à partir des fichiers .feature
dart run build_runner build

# 2. Exécuter
flutter test test/auth_test.dart     # une feature
flutter test                         # toute la suite
```

## Périmètre couvert

### Scénarios automatisés (feature `Authentification`)

| # | Scénario | Vérifie |
|---|----------|---------|
| 1 | Formulaire de connexion vide | Message « Veuillez entrer votre email » |
| 2 | Email au format invalide | Message « Veuillez entrer un email valide » |
| 3 | Mot de passe manquant | Message « Veuillez entrer votre mot de passe » |
| 4 | Accès à l'écran d'inscription | Navigation vers « Créer un compte » |
| 5 | Ouverture du dialogue mot de passe oublié | Affichage de la fenêtre de réinitialisation |

Ces scénarios couvrent la **validation côté client** du formulaire de connexion,
la **navigation** entre écrans et l'**ouverture d'un dialogue** — sans dépendance
réseau, donc **déterministes**.

## Hors périmètre des tests UI automatisés (et pourquoi)

Certaines exigences ne relèvent **pas** d'un test d'interface piloté par
`bdd_widget_test`, qui n'observe que l'interface de l'application :

| Domaine | Pourquoi hors périmètre | Couverture appropriée |
|---------|-------------------------|-----------------------|
| Écriture en base (`device_commands`, RLS) | Se passe côté serveur Supabase, invisible depuis l'UI | Tests d'intégration serveur |
| Worker MQTT (publication de commandes) | Processus séparé, hors de l'application | Tests d'intégration dédiés |
| Agent IA (STT/TTS, réponses en streaming) | Services cloud externes, résultats non déterministes | Tests manuels / d'intégration |
| Obfuscation de l'APK | Concerne le binaire compilé, pas l'app en exécution | Vérification sur l'artefact de build |

Deux critères rendent une exigence inadaptée à un test BDD-UI : elle **ne passe
pas par l'écran**, ou elle **n'est pas déterministe**. La logique métier pure
(calculs, validations) reste par ailleurs couverte par les tests unitaires
existants du dossier `test/`.

## Limites et évolutions possibles

- Les écrans nécessitant l'authentification et l'injection de dépendances
  (accueil, réglages, appareils) requièrent la mise en place de doublures
  (mocks) pour être testés en UI : évolution possible ultérieurement.
- Les scénarios peuvent être étendus au fil de l'ajout de fonctionnalités, en
  ajoutant simplement des lignes dans les fichiers `.feature`.
