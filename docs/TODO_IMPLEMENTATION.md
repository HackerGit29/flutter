# TODO – Implémentations restantes pour atteindre la vision 2026

## Administration (Admin)

- [ ] Vérifier que la navigation vers les onglets est protégée par le rôle `admin` (ex. via un guard).
- [ ] Ajouter un onglet/listing détaillé des `admin_actions` (journal des actions admin) si non déjà présent.
- [ ] Eventuellement ajouter des notifications/pop‑ups de confirmation pour les actions critiques (suspendre utilisateur, réinitialiser appareil, etc.).

## Agent‑IA (Agent‑Orchestrator)

- [ ] **Gating des fonctionnalités VIP** :
    - Implémenter un helper `isFeatureAllowed(featureName: String, userId: String) => Future<bool>` qui lit la `subscription.type` (ou la `license`) depuis Supabase.
    - Protéger les outils premium de l’agent (historique étendu, sync avancé, support prioritaire, multi‑appareils) en appelant ce helper avant l’exécution.
- [ ] **Limitation de débit des appels LLM** : envelopper les appels à Azure OpenAI (`services/agent_service.dart`) avec la même logique de `rateLimit` déjà utilisée pour les outils (ex. 5 requêtes/min par utilisateur).
- [ ] **Mécanisme de retry / back‑off** : ajouter une logique de nouvelle tentative exponentielle (avec jitter) autour des appels externes (Azure OpenAI, Supabase RPC) afin de gérer les erreurs temporaires.
- [ ] **Nettoyage des embeddings/vectors** (optionnel mais recommandé) : créer une fonction Supabase Cron qui supprime les entrées de `chat_embeddings` plus anciennes que 7 jours ou qui ré‑indexe les vecteurs si nécessaire.

## MQTT (Worker & App)

- [ ] Vérifier / implémenter la logique du worker (`workers/mqtt5-worker/index.js`) :
    1. Lire périodiquement (ou via `pg_notify`/trigger) la table `device_commands` où `status = 'pending'`.
    2. Pour chaque ligne, publier le payload JSON (`{ command (`ON|OFF|REBOOT|...`) sur le topic `device/command/<deviceId>` avec QoS 2.
    3. S’abonner au topic d’acquitement `device/command/<deviceId>/ack`.
    4. À réception d’un ACK, mettre à jour la ligne correspondante :
        - `status = 'sent'` si l’ACK indique succès,
        - `status = 'failed'` + `error_message` sinon.
    5. Gérer les reconnexions et le back‑off (déjà présent dans le README du worker).
- [ ] Ajouter des logs détaillés dans le worker pour faciliter le débogage en production (événements de lecture, publication, réception ACK, erreurs).
- [ ] S’assurer que les variables d’environnement du worker sont correctement configurées dans le pipeline Azure Container Apps :
    - `FLESPI_TOKEN` (ou distincts `FLESPI_MQTT_WORKER_TOKEN` / `FLESPI_MQTT_APP_TOKEN`)
    - `FLESPI_HOST`
    - `SUPABASE_URL`
    - `SUPABASE_SERVICE_ROLE_KEY` (ou équivalent avec droits sur `device_commands`)
- [ ] Confirmer que l’application Flutter ne publie jamais sur MQTT (aucune appel à `publish` dans `mqtt_service.dart`).
- [ ] (Optionnel) Ajouter une vue dans l’admin pour voir les commandes en attente / échouées (liste provenant de `device_commands`).

## Général

- [ ] Mettre à jour la documentation (README, `docs/...`) avec les nouvelles fonctionnalités et les instructions de déploiement du worker.
- [ ] Écrire des tests unitaires / d’intégration pour les nouveaux use‑cases admin, les helper d’auth/feature, et la logique du worker (si possible avec un mock de Supabase/MQTT).
- [ ] Vérifier la conformité avec `rules.md` (gestion des secrets, clean architecture, etc.) pour le nouveau code ajouté.

---
*Ce fichier doit être maintenu à jour au fur et à mesure que les tâches sont réalisées. Lorsqu’une tâche est terminée, cochez la case correspondante et déplacez‑la éventuellement vers un fichier `DONE.md` pour suivi.*