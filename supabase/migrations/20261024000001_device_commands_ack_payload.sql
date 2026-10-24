-- device_commands.ack_payload
--
-- Le handler ACK du worker MQTT (workers/mqtt5-worker/app.js) écrit le payload
-- renvoyé par le boîtier dans `ack_payload`. La colonne n'existait pas en base :
-- l'UPDATE échouait en 42703, si bien que le worker journalisait une erreur
-- silencieuse et laissait la commande expirer en `timeout`, même quand le
-- boîtier avait bien exécuté l'ordre (constaté en e2e le 2026-10-24).
ALTER TABLE device_commands
  ADD COLUMN IF NOT EXISTS ack_payload JSONB;
