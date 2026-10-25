# Stratégie de tests — Aricie

## 1. Vue d'ensemble

La stratégie de tests du projet Aricie suit une approche pyramidale combinant tests unitaires, tests de sécurité, tests de bout en bout (E2E) et tests de couverture. L'objectif est de garantir la fiabilité des fonctionnalités critiques (authentification, contrôle des appareils IoT, abonnements, administration) tout en assurant un niveau de sécurité conforme aux standards OWASP Mobile.

La stack technique repose sur `flutter_test`, `mocktail` pour le mocking, et `integration_test` pour les parcours E2E. La couverture est mesurée via `lcov` avec un seuil cible défini par composant.

---

## 2. Pyramide de test

```
          /\
         /  \          E2E (integration_test)
        /    \         Parcours utilisateur critiques
       /------\
      /        \       Tests de sécurité (OWASP Mobile)
     /          \      TokenManager, stockage sécurisé, JWT
    /------------\
   /              \    Tests unitaires (domain)
  /                \   Use-cases, entités, logique métier
 /------------------\
/   Tests de smoke    \  smoke test applicatif + RAG agent
```

### 2.1 Tests unitaires (domaine métier)

Situés dans `test/domain/` et `test/unit/`, ils couvrent :

- **Entités** : `User.fromJson()`, `toJson()`, `copyWith()`, validation des rôles et statuts (`test/domain/entities/user_test.dart`)
- **Use-cases** :
  - Authentification : `RegisterUser`, `LogoutUser`, `ResetPassword`, `ConfirmPasswordReset` — validation email, code invalide, mot de passe trop court
  - Administration : `GetDeviceCommands`, `GetAdminActions` — vérification des droits admin, structure des commandes
  - Licence : `RedeemProductKey` — clé valide, clé déjà utilisée, clé invalide
- **Logique métier** : `ToggleDevice`, validation email, sessions (`test/unit/domain_logic_test.dart`)

### 2.2 Tests de sécurité (OWASP Mobile)

Situés dans `test/security/owasp_mobile_test.dart`, ils couvrent :

- **M1: Improper Platform Usage** — stockage des tokens JWT dans `FlutterSecureStorage`, isolation `saveTokens`/`clearTokens`
- **M7: Client Code Quality** — détection d'expiration JWT via `needsRefresh()`, parsing du payload `exp`

### 2.3 Tests de l'agent RAG

Situés dans `test/agent_rag_smoke_test.dart`, ils couvrent :

- **Criticité des appareils** : `_matchesCritical()` — détection des appareils critiques (chauffe-eau, climatiseur, four)
- **Filtrage read-only** : `_isReadOnly()` — outils `get_*` autorisés vs `turn_*` bloqués
- **Filtrage par abonnement** : `_filterToolsForSubscription()` — abonnement free (lecture seule) vs VIP (tous les outils), downgrade

### 2.4 Tests E2E

Situés dans `test/e2e/user_journeys_test.dart` (placeholder en l'absence d'appareil ou d'environnement `integration_test` complet). Les scénarios E2E cibles sont documentés en section 4.

### 2.5 Smoke test applicatif

`test/widget_test.dart` : placeholder validant le démarrage du widget tree.

---

## 3. Couverture de code

La couverture est générée via :

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

**Seuils cibles par couche :**

| Couche | Cible | Priorité |
|--------|-------|----------|
| Entités (domain) | > 90 % | Haute |
| Use-cases (domain) | > 85 % | Haute |
| Sécurité | > 80 % | Haute |
| Services (data) | > 70 % | Moyenne |
| Présentation (widgets) | > 50 % | Moyenne |
| UI (screens) | > 30 % | Basse |

---

## 4. Scénarios de test et cas de vérification (Jira)

Les scénarios ci-dessous sont destinés à être rédigés sous forme de tickets Jira liés aux exigences fonctionnelles et techniques correspondantes. Chaque scénario inclut un identifiant, un titre, une description, des préconditions, des étapes de test et le résultat attendu.

### 4.1 Authentification

| ID | Titre | Exigence liée |
|----|-------|---------------|
| TC-AUTH-01 | Inscription avec email valide | REQ-AUTH-001 |
| TC-AUTH-02 | Inscription avec email invalide | REQ-AUTH-001 |
| TC-AUTH-03 | Connexion avec identifiants corrects | REQ-AUTH-002 |
| TC-AUTH-04 | Connexion avec mot de passe incorrect | REQ-AUTH-002 |
| TC-AUTH-05 | Demande de réinitialisation de mot de passe | REQ-AUTH-003 |
| TC-AUTH-06 | Réinitialisation avec code valide | REQ-AUTH-004 |
| TC-AUTH-07 | Réinitialisation avec code invalide ou expiré | REQ-AUTH-004 |
| TC-AUTH-08 | Déconnexion et nettoyage de session | REQ-AUTH-005 |
| TC-AUTH-09 | Refresh token automatique à expiration | REQ-AUTH-006 |
| TC-AUTH-10 | Vérification du rôle utilisateur (user/admin) | REQ-AUTH-007 |

### 4.2 Appareils et IoT

| ID | Titre | Exigence liée |
|----|-------|---------------|
| TC-DEV-01 | Activation d'un appareil (toggle on) | REQ-DEV-001 |
| TC-DEV-02 | Désactivation d'un appareil (toggle off) | REQ-DEV-001 |
| TC-DEV-03 | Renommage d'un appareil | REQ-DEV-002 |
| TC-DEV-04 | Affichage de la liste des appareils | REQ-DEV-003 |
| TC-DEV-05 | Filtrage des appareils par catégorie | REQ-DEV-004 |
| TC-DEV-06 | Délégation d'une commande vers MQTT via device_commands | REQ-DEV-005 |
| TC-DEV-07 | Statut ACK reçu après commande | REQ-DEV-005 |
| TC-DEV-08 | Connexion MQTT avec boxUid valide | REQ-DEV-006 |
| TC-DEV-09 | Reconnexion automatique en cas de perte de connexion MQTT | REQ-DEV-006 |
| TC-DEV-10 | Fallback sur FLESPI_DEFAULT_BOX_UID si aucun appareil | REQ-DEV-007 |

### 4.3 Consommation énergétique

| ID | Titre | Exigence liée |
|----|-------|---------------|
| TC-ENE-01 | Affichage de la consommation en temps réel | REQ-ENE-001 |
| TC-ENE-02 | Historique de consommation (journalier, hebdomadaire, mensuel) | REQ-ENE-002 |
| TC-ENE-03 | Agrégation des données energy_data | REQ-ENE-003 |
| TC-ENE-04 | Calcul du cumul kWh sur période | REQ-ENE-004 |
| TC-ENE-05 | Mise à jour via stream Realtime Supabase | REQ-ENE-005 |

### 4.4 Abonnements et licences

| ID | Titre | Exigence liée |
|----|-------|---------------|
| TC-SUB-01 | Activation d'un abonnement VIP via clé produit valide | REQ-SUB-001 |
| TC-SUB-02 | Refus d'une clé produit déjà utilisée | REQ-SUB-001 |
| TC-SUB-03 | Refus d'une clé produit invalide | REQ-SUB-001 |
| TC-SUB-04 | Filtrage des outils agent pour abonnement free | REQ-SUB-002 |
| TC-SUB-05 | Accès complet aux outils pour abonnement VIP | REQ-SUB-002 |
| TC-SUB-06 | Downgrade VIP -> free : perte des outils d'écriture | REQ-SUB-002 |
| TC-SUB-07 | Vérification de la validité de l'abonnement | REQ-SUB-003 |

### 4.5 Agent IA et RAG

| ID | Titre | Exigence liée |
|----|-------|---------------|
| TC-AGENT-01 | Détection de la criticité des appareils (chauffe-eau = critique) | REQ-AGENT-001 |
| TC-AGENT-02 | Appareil non critique (lampe) non marqué comme critique | REQ-AGENT-001 |
| TC-AGENT-03 | Confirmation modale pour action critique | REQ-AGENT-002 |
| TC-AGENT-04 | Requête RAG scope par owner_id | REQ-AGENT-003 |
| TC-AGENT-05 | Appel de fonction outil via LLM | REQ-AGENT-004 |
| TC-AGENT-06 | Streaming SSE typé (token/tool_pending/tool_result/done) | REQ-AGENT-005 |
| TC-AGENT-07 | Confirmation structurée via `confirmed_tool_call` | REQ-AGENT-006 |
| TC-AGENT-08 | Fallback deepSeek si Azure OpenAI indisponible | REQ-AGENT-007 |

### 4.6 Administration

| ID | Titre | Exigence liée |
|----|-------|---------------|
| TC-ADMIN-01 | Listing des commandes appareil en attente | REQ-ADMIN-001 |
| TC-ADMIN-02 | Refus d'accès pour utilisateur non-admin | REQ-ADMIN-001 |
| TC-ADMIN-03 | Consultation de l'historique des actions admin | REQ-ADMIN-002 |
| TC-ADMIN-04 | Création d'un boîtier (box) | REQ-ADMIN-003 |
| TC-ADMIN-05 | Création d'appareils pour un boîtier | REQ-ADMIN-004 |
| TC-ADMIN-06 | Attribution d'un boîtier à un utilisateur | REQ-ADMIN-005 |
| TC-ADMIN-07 | Suspension / activation d'un utilisateur | REQ-ADMIN-006 |

### 4.7 Sécurité

| ID | Titre | Exigence liée |
|----|-------|---------------|
| TC-SEC-01 | Stockage du JWT dans FlutterSecureStorage | REQ-SEC-001 |
| TC-SEC-02 | Nettoyage complet des tokens à la déconnexion | REQ-SEC-001 |
| TC-SEC-03 | Détection d'un token JWT expiré | REQ-SEC-002 |
| TC-SEC-04 | Vérification RLS sur les tables Supabase | REQ-SEC-003 |
| TC-SEC-05 | user_id extrait du JWT uniquement (pas du body) | REQ-SEC-004 |
| TC-SEC-06 | Rate limiting sur les appels agent | REQ-SEC-005 |
| TC-SEC-07 | Vérification d'appartenance (ownership) des appareils | REQ-SEC-006 |

### 4.8 Parcours E2E critiques

| ID | Titre | Exigence liée |
|----|-------|---------------|
| TC-E2E-01 | Parcours complet : inscription -> connexion -> tableau de bord | REQ-E2E-001 |
| TC-E2E-02 | Parcours complet : activation d'un appareil depuis le chat IA | REQ-E2E-002 |
| TC-E2E-03 | Parcours admin : création d'un boîtier et d'appareils | REQ-E2E-003 |
| TC-E2E-04 | Parcours abonnement : activation VIP et accès aux outils | REQ-E2E-004 |
| TC-E2E-05 | Parcours MQTT : commande -> device_commands -> ACK | REQ-E2E-005 |

---

## 5. Outillage et commandes

```bash
# Exécuter tous les tests
flutter test

# Tests avec couverture
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Analyser le code source
flutter analyze

# Construire en release
flutter build apk --obfuscate --split-debug-info=build/obfuscation/
```

---

## 6. CI/CD et gates de qualité

Les tests sont intégrés au pipeline CI avec les gates suivantes :

1. **flutter analyze** — zéro warning (bloquant)
2. **Tests unitaires** — 100 % de réussite (bloquant)
3. **Tests de sécurité** — 100 % de réussite (bloquant)
4. **Couverture minimale** — vérifiée par couche (non bloquant en `warn`, bloquant en `fail`)

---

## 7. État actuel et prochaines étapes

### Couvert actuellement

- Entité User : parsing JSON, copie, sérialisation, validation de rôle
- Use-cases auth : inscription, connexion, déconnexion, reset password, confirm reset
- Use-cases admin : device commands, admin actions (avec contrôle de droits)
- Use-cases licence : redemption de clé produit
- Sécurité OWASP : stockage JWT, détection expiration
- Agent RAG : criticité, filtrage read-only, filtrage par abonnement

### À implémenter

- Tests de repositories (data layer) avec mock Supabase
- Tests de présentation (widgets et screens) avec `WidgetTester`
- Tests d'intégration des services (MQTT, Agent SSE, Voice)
- Tests E2E sur appareil réel ou émulateur
- Tests de performance et de charge
- Tests de régression visuelle
