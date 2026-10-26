-- Migration: Admin RBAC — niveaux d'accès + vue agrégée couverture
-- Date: 2026-10-26
-- Ref: docs/cahier-des-charges-admin-dashboard.md §4.2

-- ============================================================
-- 1. users.admin_level : RBAC fin pour le backoffice web
--    NULL = utilisateur normal. Renseigné uniquement si role='admin'.
--    viewer    : lecture seule (commerciaux)
--    operator  : écritures opérationnelles (boîtiers, abonnements…)
--    super_admin : rôle, licences, reset, audit
-- ============================================================
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS admin_level TEXT
    CHECK (admin_level IN ('viewer', 'operator', 'super_admin'));

-- Garde-fou : un admin_level n'a de sens que pour un compte admin
DO $$ BEGIN
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint WHERE conname = 'admin_level_requires_admin_role'
    ) THEN
      ALTER TABLE users
        ADD CONSTRAINT admin_level_requires_admin_role
        CHECK (admin_level IS NULL OR role = 'admin');
    END IF;
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- ============================================================
-- 2. Vue agrégée de couverture (utilisée par l'API /v1/geo/coverage)
--    security_invoker : la vue s'exécute avec les droits de l'appelant,
--    donc les policies RLS boxes/users (private.is_admin()) s'appliquent.
--    Sans cela, la vue contournerait la RLS et exposerait les géolocs.
-- ============================================================
DROP VIEW IF EXISTS admin_coverage_view;
CREATE VIEW admin_coverage_view
WITH (security_invoker = true) AS
SELECT
  b.id AS box_id,
  b.latitude,
  b.longitude,
  b.geo_precision,
  b.status,
  b.firmware_version,
  b.installed_at,
  u.id AS user_id,
  u.status AS user_status,
  s.type AS sub_type,
  s.is_active AS sub_active
FROM boxes b
JOIN users u ON u.id = b.user_id
LEFT JOIN subscriptions s ON s.user_id = u.id AND s.is_active
WHERE b.latitude IS NOT NULL AND b.longitude IS NOT NULL;

GRANT SELECT ON admin_coverage_view TO authenticated;
