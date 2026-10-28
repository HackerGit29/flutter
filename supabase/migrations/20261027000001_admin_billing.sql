-- Migration backoffice : gestion des licences + audit des abonnements
-- Ref: docs/cahier-des-charges-admin-dashboard.md §5.3.9
--
-- 1. licenses : la table n'avait aucun statut de vie. Le backoffice a besoin
--    de tracer une révocation (motif obligatoire, §6.9) et de distinguer
--    « révoquée » de « expirée ». Le statut n'est pas stocké en colonne
--    dérivée : il est calculé côté API (revoked_at -> revoked,
--    expiration_date < NOW() -> expired, sinon active) pour éviter une
--    dénormalisation qui dériverait de la vérité.
-- 2. admin_action_type : valeur manquante pour l'écriture PATCH
--    /v1/subscriptions/:id (A11 — opérateur billing).

ALTER TABLE licenses
  ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS revoke_reason TEXT;

ALTER TYPE admin_action_type ADD VALUE IF NOT EXISTS 'update_subscription';
