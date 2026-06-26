# TODO – Implémentations restantes pour atteindre la vision 2026

## Administration (Admin)

- [ ] **Navigation protégée par rôle admin** : Le lien admin est masqué côté profile (`isAdmin`), mais l'`AdminDashboardScreen` n'a pas de guard dans `initState`/`build`. Tout utilisateur qui navigue directement (URL, code) peut y accéder. RLS backend OK, frontend manquant.
- [ ] **Ajouter un onglet/listing détaillé des `admin_actions`** : Les actions sont bien loggées en base (14 use-cases avec `logAdminAction()`), mais aucune UI ne les affiche. Le dashboard admin a 4 tabs (Boîtiers, Utilisateurs, Licences, Synchronisations) — pas d'onglet Actions.
- [ ] **Notifications/pop-ups pour actions critiques** : ✅ Reset boîtier et Assign ont des confirmations. ❌ Force sync et Suspend user n'ont **pas** de confirmation dialog (exécution immédiate + SnackBar).

## Utilisateurs (License user)

- [ ] **Clé produit → VIP depuis l'app** : Non implémenté. L'infrastructure VIP existe (`SubscriptionType`, `Role`, `IsFeatureAllowed` use case, `PremiumGateWidget`), mais l'utilisateur ne peut pas saisir sa clé produit depuis l'app.
- [ ] Vérifier que l'utilisateur peut ajouter sa clé produit et faire basculer son compte vers VIP depuis l'app sans nécessairement l'aide d'un admin. Si oui, mettre en place un système d'affichage conditionnel qui affiche la couronne premium account VIP lottifile premium.json à la place de la PP de l'utilisateur premium.
- [ ] **Menu settings pour clé produit** : Non implémenté. Pas de champ de saisie de clé produit dans les settings.
- [ ] **Lottie confirmation premium** : Non implémenté. success_premium.json` / `error_premium.json`.

## Agent‑IA (Agent‑Orchestrator)

- [ ] **Gating des fonctionnalités VIP** : Infrastructure partielle (`IsFeatureAllowed`, `PremiumGateWidget`), mais **aucun gating côté agent** — le LLM est accessible à tous, outils premium non protégés.
- [ ] **Limitation de débit des appels LLM** : ❌ Aucun rate-limiting dans `agent_service.dart`. Les appels partent sans cap.
- [ ] **Mécanisme de retry / back‑off** : ❌ Aucun retry dans `agent_service.dart`. Un échec POST → erreur immédiate, pas de nouvelle tentative.
- [ ] **Nettoyage des embeddings/vectors** : ❌ Aucun cron/cleanup. `chat_embeddings` s'accumule sans TTL.

## MQTT (Worker & App)

- [ ] Worker MQTT5 :
    1. ✅ Lecture périodique `device_commands` (`claimPendingCommand()`, interval 1s)
    2. ✅ Publication sur topic `aricie/v1/boxes/${boxUid}/relays/${relayIndex}/cmd` QoS 1
    3. ✅ Souscription ACK `aricie/v1/boxes/+/relays/+/ack`
    4. ✅ Mise à jour status à réception ACK (`acknowledged` / `failed`)
    5. ✅ Reconnexion (`reconnectPeriod: 5000`, handler `reconnect`)
- [ ] **Logs détaillés worker** : ✅ `console.log`/`console.error` extensifs (connexion, subscribe, télémétrie, ACK, claim, publish, timeout, reconnexion).
- [ ] **Variables d'environnement worker** : ✅ Configurées dans Azure Container Apps (`FLESPI_MQTT_WORKER_TOKEN`, `SUPABASE_SERVICE_ROLE_KEY`, etc.).
- [ ] **Flutter ne publie jamais sur MQTT** : ✅ `MqttService` ne contient aucun appel à `.publish()`. Toute commande passe par `device_commands`.
- [ ] **Vue admin device_commands** : ❌ Aucune UI pour voir les commandes en attente/échouées. Aucune occurrence dans `lib/screens/admin/`.

## Général

- [x] **Mettre à jour la documentation** (README, `docs/...`) avec les nouvelles fonctionnalités et les instructions de déploiement du worker. *(Fait le 2026-06-26)*
- [ ] **Tests unitaires / d'intégration** : Partiel (22 tests passent). Manquent des tests pour les use-cases admin, le helper auth/feature, et la logique worker mockée.
- [ ] **Vérifier la conformité avec `rules.md`** : À faire — gestion des secrets, clean architecture, etc.

---
*Ce fichier doit être maintenu à jour au fur et à mesure que les tâches sont réalisées. Lorsqu'une tâche est terminée, cochez la case correspondante et déplacez‑la éventuellement vers un fichier `DONE.md` pour suivi.*
