# Bilan de projet — Aricie (ETSIA, seconde version)

> Les sections issues du code, du CHANGELOG, des supports de présentation et du
> suivi Jira/planning sont renseignées. Il reste **deux points** à compléter par
> l'équipe, présentés sous forme de **tableaux à remplir** en §5 : les **risques**
> et le **budget propre à Aricie**. Le RETEX organisationnel (§6) et les
> difficultés organisationnelles (§4) sont pré-rédigés et **à valider** par
> l'équipe.

## 1. Rappel du projet et objectifs

Aricie est une application de **suivi et de pilotage de la consommation
énergétique** couplée à des objets connectés (boîtiers ESP32), avec un assistant
IA. La Partie 3 vise la **seconde version** du prototype : consolider le MVP et
livrer les **fonctionnalités secondaires**, avec vérification (tests) et retours
utilisateurs.

**Contexte initial** : face à la hausse des coûts énergétiques et aux limites des
dispositifs existants, Aricie propose un outil centralisé de suivi et de gestion
en temps réel de la consommation énergétique, capable de détecter les anomalies,
d'envoyer des alertes personnalisées et d'améliorer l'expérience utilisateur.

**Problématique** : comment concevoir un système intelligent et centralisé
permettant un suivi en temps réel de la consommation énergétique, capable de
détecter les anomalies, d'optimiser l'utilisation de l'énergie et de réduire les
coûts, tout en améliorant l'expérience utilisateur ?

**Objectifs fixés en amont** :

1. Réduire la consommation énergétique globale de **10 à 20 %**, grâce à une
   meilleure gestion des pics.
2. Améliorer l'efficacité de la gestion des équipements énergivores, grâce à un
   système d'alertes automatiques.
3. Permettre un **suivi en temps réel** via une application mobile.
4. Réduire les coûts des factures électriques.

## 2. Objectifs atteints / non atteints

| Objectif | Statut | Commentaire |
|----------|--------|-------------|
| MVP fonctionnel de bout en bout | Atteint | Chaîne complète app ↔ Supabase ↔ boîtier ESP32 opérationnelle (cf. §3). |
| Fonctionnalités secondaires de la V2 | Atteint | Voir §3 (assistant IA, statistiques, conseils, mises à jour OTA…). |
| Vérification (tests fonctionnels) | Atteint (partiel) | Tests unitaires + **9 scénarios BDD** (authentification + réinitialisation), suite complète à **94 tests au vert**. Couverture ciblée sur les écrans testés ; d'autres écrans restent à couvrir. |
| Retours utilisateurs | Atteint | Séance de démonstration, **16 répondants**, note globale **4,38/5**, **NPS +44** (cf. `synthese-retours.md`). |
| Publication / mise à jour | Atteint | Release **1.5.1** publiée (CI automatisée sur tag) + mise à jour in-app (OTA). |

**Objectifs métier fixés en amont (cf. §1)** :

- *Suivi en temps réel via application mobile* — **atteint** (puissance
  instantanée, indicateur live, historique et statistiques).
- *Réduire la consommation de 10 à 20 %* — **non démontré à ce stade** : les
  leviers sont livrés (détection des pics, pilotage des appareils, conseils), mais
  la réduction effective n'a pas pu être mesurée faute de déploiement sur une
  durée suffisante.
- *Gérer les équipements énergivores via des alertes automatiques* —
  **partiellement atteint** : identification des appareils énergivores et conseils
  d'économie livrés ; les alertes par seuil configurable restent à finaliser.
- *Réduire les coûts de factures* — **non mesuré** (corollaire de la réduction de
  consommation, même limite).

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

- **Charge du Sprint 1 sous-estimée** : plusieurs récits du premier sprint
  (29/06–06/07) étaient encore *en cours* ou *à faire* à sa clôture et ont dû être
  reportés en semaine 2, décalant d'autant la phase de consolidation.
- **Consolidation compressée en fin de projet** : documentation, tests, collecte
  des retours et gestion de projet se sont concentrés sur la semaine 2, en
  parallèle de la finalisation des alertes et de l'IoT — période dense et à faible
  marge.
- **Dépendances entre lots** : les tâches de test et de retours utilisateurs
  dépendaient de la stabilisation préalable des fonctionnalités et du boîtier, ce
  qui les a naturellement placées en fin de planning.

> *À compléter par l'équipe : communication interne, coordination entre les cinq
> membres, ressenti sur le respect des délais.*

## 5. Gestion de projet

- **Processus de développement** (outillé, factuel) : commits *Conventional
  Commits*, revue par *pull request* (gabarit imposé) avec relecture du
  CODEOWNER, contrôles d'intégration continue (`flutter analyze` + `flutter
  test`) et règles de protection de branche.
- **Méthode et organisation** : gestion **agile (Scrum)** sur **deux sprints
  hebdomadaires** — Sprint 1 (29 juin–6 juillet) puis Sprint 2 (6–13 juillet) —
  suivis dans **Jira** (backlog, tableau Scrum, estimation en points). Le travail
  était structuré en épopées `ARI-*` : fonctionnelles (AUTH, REALTIME, HISTORY,
  DEVICES, AI-SUPPORT, IOT, ADMIN, ALERTS) et transverses (DOC, TEST, FEEDBACK,
  GESTION DE PROJET). Équipe de **cinq membres** (DL, BM, ND, OA, TL).
- **Répartition des tâches** (principaux lots par membre) :
  - **ND** : authentification, suivi temps réel, historique, automatisation des
    tests (Cucumber), formulaire de retours et synthèse, schéma de topologie
    réseau, rédaction du bilan.
  - **BM** : assistant IA (chatbot + recommandations), gestion des appareils,
    firmware ESP32 (envoi de la consommation, réception des commandes), alertes,
    stratégie de tests, documentation du code, production de la vidéo commerciale.
  - **TL** : gestion des appareils, administration (comptes et appareils),
    exécution et rapport des tests, finalisation du planning réel, indicateurs
    d'avancement (RAF, risques, budget).
  - **OA** : modélisation du boîtier, schéma électrique, documentation
    (installation, pré-requis matériels/logiciels, API).
  - **DL** : montage électronique, maquette IoT, support de présentation,
    organisation des sessions de démonstration, tenue du backlog Jira.
- **Planning prévisionnel vs réel** : le **prévisionnel** plaçait le socle
  applicatif et l'IoT sur le Sprint 1, puis la finalisation, la documentation, les
  tests, les retours et la vidéo sur le Sprint 2 (échéance 13 juillet). En
  **réel** (cf. planning fourni), le développement s'est concentré du 29 juin au
  10 juillet : la plupart des épopées de développement bouclées en semaine 1, la
  semaine 2 (6–10 juillet) regroupant documentation, tests, retours et gestion de
  projet, avec une finalisation tardive des **alertes** (8 juillet) et de l'IoT.
  **Écart principal** : un Sprint 1 surchargé (récits reportés) et une phase de
  consolidation resserrée en fin de projet.
- **Suivi** : backlog et tableau **Scrum dans Jira**, sprints hebdomadaires,
  estimation en points ; un lot dédié « Gestion de projet » (`ARI-PM`) couvrait la
  tenue du backlog, la finalisation du planning et les indicateurs d'avancement.
- **Risques** : suivis via l'item `ARI-PM-04` (indicateurs : RAF, risques,
  budget). *Tableau à compléter par l'équipe :*

| Risque | Probabilité | Impact | Mesure de mitigation |
|--------|-------------|--------|----------------------|
|  |  |  |  |
|  |  |  |  |
|  |  |  |  |

- **Budget** : *à compléter par l'équipe — budget propre à Aricie* (NB : le
  fichier « Budget_WaveOps » concerne un autre projet, reconnaissance gestuelle
  Kinect/Leap Motion, et ne s'applique pas ici).

| Poste | Montant prévu | Montant réel | Référence / détail |
|-------|---------------|--------------|--------------------|
| Matériel (ESP32, capteurs, relais…) |  |  |  |
| Hébergement cloud (Supabase, Azure, Flespi) |  |  |  |
| Connexion / données |  |  |  |
| Ressources humaines |  |  |  |
| **Total** |  |  |  |
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

- **La cadence Scrum en sprints courts** a donné une visibilité claire sur
  l'avancement (backlog Jira, épopées, estimation en points) et a permis de
  découper un périmètre large en lots assignables.
- **La spécialisation par lot** (applicatif, IoT, tests, documentation, retours) a
  fait avancer les chantiers en parallèle, au prix de dépendances à surveiller
  entre le développement et les activités aval (tests, retours utilisateurs).
- **Leçon principale** : mieux calibrer la charge du premier sprint pour éviter le
  report en fin de projet, et réserver plus tôt du temps à la consolidation
  (documentation, tests, retours).

> *À valider / enrichir par l'équipe : ce qui a le mieux fonctionné dans la
> collaboration, les outils de communication, ce que vous referiez autrement.*

## 7. Perspectives

- **Fiabiliser la mesure de consommation** : câblage/calibration du capteur de
  courant, voire capteur mieux adapté aux faibles charges (ACS712 5 A ou pince
  ampèremétrique) pour des mesures fines.
- **Corriger la lisibilité en thème sombre** (retour utilisateur direct).
- **Élargir la vérification** : plus de scénarios BDD sur d'autres écrans,
  simulation (mock) des services pour tester les parcours complets.
- **Consolider les retours** : panel de test plus large et plus varié
  (au-delà des étudiants).
- **Suite du projet — évolutions produit envisagées** :
  - *Offres et tarification* : étoffer les paliers d'abonnement au-delà de
    FREE/VIP (par ex. Premium, puis Famille/Pro), déblocage de fonctionnalités par
    palier et facturation mensuelle ou annuelle.
  - *Couverture multi-boîtiers du foyer* : rendre paramétrable le nombre de
    boîtiers par logement, avec gestion par pièces/zones et vue consolidée du
    foyer.
  - *Ergonomie et expérience* : parcours d'accueil guidé (onboarding),
    personnalisation du tableau de bord, accessibilité renforcée (contrastes,
    tailles de texte), dans le prolongement des retours utilisateurs.
  - *Coût réel et budget* : saisie du tarif du kWh (et heures pleines/creuses)
    pour afficher la consommation en francs et estimer la facture à venir —
    matérialise directement l'objectif de réduction des coûts.
  - *Alertes et automatisations* : finaliser les seuils d'alerte configurables,
    ajouter la programmation horaire (extinction/allumage planifié) et des
    scénarios (règles conditionnelles).
  - *Intelligence proactive* : détection d'anomalies et prévisions de
    consommation par l'assistant IA, comparaison à des profils de foyers
    similaires.
  - *Intégrations et exports* : rapports hebdomadaires/mensuels, export PDF/CSV,
    ouverture vers les assistants domotiques (Google Home, Alexa).
  - *Fiabilité de la mesure* : passage à une mesure de puissance **réelle**
    (tension + courant) pour lever le biais actuel, et support de capteurs
    additionnels.
  - *Distribution* : publication sur les stores (Play Store / App Store) en
    complément de la mise à jour OTA, et déclinaison tablette/web.
- **Diffusion** : présentation et démonstration au **salon X5**.
