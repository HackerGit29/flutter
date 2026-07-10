# Bilan de projet — Aricie (ETSIA, seconde version)

> Les sections issues du code et du CHANGELOG sont renseignées et **validées** ;
> les `[à compléter — équipe]` relèvent du vécu et de la gestion du groupe
> (objectifs initiaux, planning, budget, organisation) et doivent être
> renseignés collectivement.

## 1. Rappel du projet et objectifs

Aricie est une application de **suivi et de pilotage de la consommation
énergétique** couplée à des objets connectés (boîtiers ESP32), avec un assistant
IA. La Partie 3 vise la **seconde version** du prototype : consolider le MVP et
livrer les **fonctionnalités secondaires**, avec vérification (tests) et retours
utilisateurs.

Objectifs initiaux (ingénierie des exigences) : `[à compléter — équipe :
rappeler les objectifs et exigences fixés en amont]`

## 2. Objectifs atteints / non atteints

| Objectif | Statut | Commentaire |
|----------|--------|-------------|
| MVP fonctionnel de bout en bout | Atteint | Chaîne complète app ↔ Supabase ↔ boîtier ESP32 opérationnelle (cf. §3). |
| Fonctionnalités secondaires de la V2 | Atteint | Voir §3 (assistant IA, statistiques, conseils, mises à jour OTA…). |
| Vérification (tests fonctionnels) | Atteint (partiel) | Tests unitaires + **9 scénarios BDD** (authentification + réinitialisation), suite complète à **94 tests au vert**. Couverture ciblée sur les écrans testés ; d'autres écrans restent à couvrir. |
| Retours utilisateurs | Atteint | Séance de démonstration, **12 répondants**, note globale **4,42/5**, **NPS +42** (cf. `synthese-retours.md`). |
| Publication / mise à jour | Atteint | Release **1.5.1** publiée (CI automatisée sur tag) + mise à jour in-app (OTA). |

## 3. Fonctionnalités réalisées

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

### Techniques

- **Architecture MQTT** : instances multiples entre écrans → refonte en
  singleton partagé (`get_it`), gestion des reconnexions et des `StreamBuilder`.
- **Agrégations SQL** : un `GROUP BY` dans un `SELECT INTO` provoquait
  `TOO_MANY_ROWS` et bloquait les agrégations hebdo/mensuel/annuel.
- **Assistant IA — flux de *tool calls*** : boucle de confirmation d'action et
  absence de réponse après confirmation ; plus tard, l'agent répondait
  « 0 appareil » à cause d'une requête portant sur des colonnes inexistantes
  (`is_active`/`is_blocked` au lieu de `status`) sur la table `boxes`.
- **Chaîne CI / mise à jour** : cohérence du `buildNumber` de l'APK avec
  `version.json`.
- **Tests BDD** : `flutter_gherkin` incompatible avec Dart 3 → migration vers
  `bdd_widget_test` (cf. `strategie-tests.md`).
- **Contrôle des appareils** : commandes envoyées en double depuis le chatbot
  (champ de saisie non désactivé pendant la génération) → corrigé.
- **Affichage temps réel** : la consommation journalière et le graphe restaient
  figés sur la valeur du chargement (flux temps réel non répercuté) → corrigé.
- **Intégration IoT (boîtier réel)** : connexion MQTT TLS impossible faute
  d'horloge synchronisée sur l'ESP32 (certificat rejeté → ajout NTP) ; capteur
  de température/humidité (DHT22) sensible au câblage (valeurs erronées sur
  contact instable) ; capteur de courant (ACS712) nécessitant une calibration du
  zéro et dont la résolution est insuffisante pour de très faibles charges.

### Organisationnelles

`[à compléter — équipe : répartition des tâches, communication, coordination,
respect des délais, dépendances entre membres…]`

## 5. Gestion de projet

- **Processus de développement** (outillé, factuel) : commits *Conventional
  Commits*, revue par *pull request* (gabarit imposé) avec relecture du
  CODEOWNER, contrôles d'intégration continue (`flutter analyze` + `flutter
  test`) et règles de protection de branche.
- **Planning prévisionnel vs réel** : `[à compléter — équipe : comparer prévu et
  réalisé, écarts et causes]`
- **Suivi** : `[à compléter — équipe : outil (Jira/Scrum…), rituels]`
- **Risques** : `[à compléter — équipe : risques identifiés et mesures]`
- **Budget** : `[à compléter — équipe : prévisionnel vs réel]`
- **Reste à faire** : fiabiliser la mesure de courant (câblage/capteur adapté) ;
  corriger la lisibilité des textes en thème sombre (retour utilisateur) ;
  élargir la couverture de tests à d'autres écrans ; consolider les retours avec
  un panel élargi.

## 6. Retours d'expérience

### Techniques

- **Chaîne IoT de bout en bout** : le diagnostic (broker, jeton, câblage,
  synchronisation d'horloge pour le TLS) a montré l'importance de vérifier
  chaque maillon séparément plutôt que de supposer une panne globale.
- **Supabase / architecture** : la puissance de RLS + Edge Functions, mais aussi
  la nécessité de garder le code aligné sur le schéma réel de la base (l'incident
  « 0 appareil » venait d'un simple écart de nom de colonne).
- **Temps réel côté application** : bien distinguer un chargement ponctuel (photo
  à l'ouverture) d'un flux continu ; plusieurs affichages devaient être
  recalculés à chaque nouvelle donnée.
- **Outillage de test** : le choix d'un outil BDD compatible avec la version du
  langage (`bdd_widget_test`) plutôt que l'outil « historique » incompatible a
  débloqué l'automatisation et l'exécution en CI.
- **Livraison** : l'automatisation de la release sur *tag* (build + `version.json`
  + publication) fiabilise et simplifie la distribution.

### Organisationnels

`[à compléter — équipe : travail d'équipe, méthode, outils, communication, ce qui
a bien marché, ce qu'on referait autrement]`

## 7. Perspectives

- **Fiabiliser la mesure de consommation** : câblage/calibration du capteur de
  courant, voire capteur mieux adapté aux faibles charges (ACS712 5 A ou pince
  ampèremétrique) pour des mesures fines.
- **Corriger la lisibilité en thème sombre** (retour utilisateur direct).
- **Élargir la vérification** : plus de scénarios BDD sur d'autres écrans,
  simulation (mock) des services pour tester les parcours complets.
- **Consolider les retours** : panel de test plus large et plus varié
  (au-delà des étudiants).
- **Suite du projet** : `[à compléter — équipe : évolutions envisagées, salon
  X5…]`
