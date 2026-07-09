# Bilan de projet — Aricie (ETSIA, seconde version)

> Les sections marquées **« [factuel — dépôt] »** sont pré-remplies à partir du
> code et du CHANGELOG ; à **valider** par l'équipe. Les `[à compléter]`
> relèvent du vécu et de la gestion de l'équipe (planning, budget, organisation)
> et doivent être renseignés par le groupe.

## 1. Rappel du projet et objectifs

Aricie est une application de **suivi et de pilotage de la consommation
énergétique** couplée à des objets connectés (boîtiers ESP32), avec un assistant
IA. La Partie 3 vise la **seconde version** du prototype : consolider le MVP et
livrer les **fonctionnalités secondaires**, avec vérification et retours
utilisateurs.

Objectifs initiaux : `[à compléter — rappeler les objectifs fixés en ingénierie
des exigences]`

## 2. Objectifs atteints / non atteints

| Objectif | Statut | Commentaire |
|----------|--------|-------------|
| MVP fonctionnel de bout en bout | `[atteint / partiel]` | `[à valider]` |
| Fonctionnalités secondaires de la V2 | `[atteint / partiel]` | voir §3 |
| Vérification (tests fonctionnels) | atteint (partiel) | tests unitaires + BDD sur l'authentification |
| Retours utilisateurs | `[à compléter selon la séance de démo]` | cf. `synthese-retours.md` |
| `[autre objectif]` | `[…]` | `[…]` |

## 3. Fonctionnalités réalisées — [factuel — dépôt]

*(D'après le CHANGELOG et le code ; à valider.)*

- **Authentification** : connexion, réinitialisation de mot de passe, édition de
  profil, préférences de notification.
- **Multi-utilisateurs** : rôles (admin / standard / VIP), isolation stricte des
  données (RLS), provisioning des boîtiers/appareils par l'admin.
- **Gestion des appareils** : consultation, pilotage via une file de commandes
  (`device_commands`) traitée par le worker MQTT.
- **Suivi de consommation temps réel** : puissance instantanée, indicateur live.
- **Historique et statistiques** : agrégations jour/semaine/mois/année,
  détection des pics de consommation.
- **Conseils d'économie d'énergie** : bannière de conseils (génération planifiée).
- **Assistant IA** : chatbot conversationnel (RAG pgvector + Azure OpenAI,
  streaming SSE), interaction vocale (STT/TTS).
- **Abonnements / licences** : FREE/VIP, clés produit et rotation.
- **Mises à jour in-app** : distribution OTA de l'APK.

## 4. Difficultés rencontrées

### Techniques — [factuel — dépôt]
*(Documentées dans le CHANGELOG ; à valider/reformuler.)*

- **Architecture MQTT** : instances multiples entre écrans → refonte en
  singleton partagé (`get_it`), gestion des reconnexions et des `StreamBuilder`.
- **Agrégations SQL** : un `GROUP BY` dans un `SELECT INTO` provoquait
  `TOO_MANY_ROWS` et bloquait les agrégations hebdo/mensuel/annuel.
- **Assistant IA** : boucle infinie de confirmation d'action et absence de
  réponse après confirmation (flux de *tool calls*).
- **Chaîne CI / mise à jour** : cohérence du `buildNumber` de l'APK avec
  `version.json`.
- **Tests BDD** : l'outil `flutter_gherkin` s'est révélé incompatible avec Dart
  3 → migration vers `bdd_widget_test` (cf. `strategie-tests.md`).

### Organisationnelles
`[à compléter — répartition des tâches, communication, coordination, respect
des délais, dépendances entre membres…]`

## 5. Gestion de projet

- **Planning prévisionnel vs réel** : `[à compléter — comparer ce qui était
  prévu et ce qui a réellement été fait, avec les écarts et leurs causes]`
- **Suivi** : `[outil utilisé — Jira/Scrum, rituels de communication]`
- **Risques** : `[à compléter — risques identifiés et mesures prises]`
- **Budget** : `[à compléter — budget prévisionnel vs réel]`
- **Reste à faire** : `[à compléter]`

## 6. Retours d'expérience

### Techniques
`[à compléter — ce que l'équipe a appris : MQTT/IoT, Supabase/RLS, IA/RAG,
tests, CI/CD… ce qui a bien marché, ce qu'on referait autrement]`

### Organisationnels
`[à compléter — travail d'équipe, méthode, outils, communication]`

## 7. Perspectives

`[à compléter — évolutions envisagées pour la suite / le salon X5]`
