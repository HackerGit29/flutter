-- Migration: Admin geo — géolocalisation boîtiers + zones de couverture + événements analytics + notes support
-- Date: 2026-10-26
-- Ref: docs/cahier-des-charges-admin-dashboard.md §4.1

-- ============================================================
-- 1. boxes : géolocalisation à l'installation
-- ============================================================
ALTER TABLE boxes
  ADD COLUMN IF NOT EXISTS latitude  DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS geo_precision TEXT
    CHECK (geo_precision IN ('exact', 'approx', 'city', 'manual')),
  ADD COLUMN IF NOT EXISTS installed_at TIMESTAMPTZ;

-- Index partiel : seuls les boîtiers géolocalisés sont indexés
CREATE INDEX IF NOT EXISTS idx_boxes_geo ON boxes (latitude, longitude)
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- ============================================================
-- 2. coverage_zones : zones de couverture définies par l'entreprise
-- ============================================================
CREATE TABLE IF NOT EXISTS coverage_zones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,                        -- 'Lyon Est', 'Rennes agglo'
  center_lat DOUBLE PRECISION NOT NULL,
  center_lng DOUBLE PRECISION NOT NULL,
  radius_km DOUBLE PRECISION NOT NULL CHECK (radius_km > 0),
  target_clients INT DEFAULT 0,              -- objectif commercial
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE coverage_zones ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    DROP POLICY IF EXISTS coverage_zones_admin ON coverage_zones;
    CREATE POLICY coverage_zones_admin ON coverage_zones
      FOR ALL TO authenticated USING (private.is_admin());
EXCEPTION WHEN others THEN null; END $$;

-- ============================================================
-- 3. analytics_events : événements produit (funnels, rétention, cohortes)
--    Écriture : service role uniquement (Edge Functions).
--    Lecture : admin via RLS.
-- ============================================================
CREATE TABLE IF NOT EXISTS analytics_events (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  box_id UUID REFERENCES boxes(id) ON DELETE SET NULL,
  event TEXT NOT NULL,          -- 'app_open','chat_message','tool_confirmed','tip_shown'…
  properties JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_analytics_events_user ON analytics_events(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_analytics_events_type ON analytics_events(event, created_at DESC);

ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    DROP POLICY IF EXISTS analytics_events_admin_select ON analytics_events;
    CREATE POLICY analytics_events_admin_select ON analytics_events
      FOR SELECT TO authenticated USING (private.is_admin());
    -- Pas de policy INSERT/UPDATE/DELETE : écriture service role uniquement
EXCEPTION WHEN others THEN null; END $$;

-- ============================================================
-- 4. admin_notes : notes internes support (jamais visibles côté client)
-- ============================================================
CREATE TABLE IF NOT EXISTS admin_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID NOT NULL REFERENCES users(id),
  target_type TEXT NOT NULL CHECK (target_type IN ('user', 'box', 'subscription')),
  target_id UUID NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_notes_target
  ON admin_notes(target_type, target_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_notes_admin ON admin_notes(admin_id);

ALTER TABLE admin_notes ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    DROP POLICY IF EXISTS admin_notes_admin_all ON admin_notes;
    CREATE POLICY admin_notes_admin_all ON admin_notes
      FOR ALL TO authenticated USING (private.is_admin())
      WITH CHECK (private.is_admin());
EXCEPTION WHEN others THEN null; END $$;
