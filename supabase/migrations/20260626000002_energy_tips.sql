-- Migration: energy tips (daily cron + realtime push)
-- Date: 2026-06-26
-- Spec: docs/superpowers/specs/2026-06-26-energy-tips-banner-design.md

-- 1. daily_energy_tip : 1 ligne par user par jour, UPSERT sur user_id
CREATE TABLE IF NOT EXISTS daily_energy_tip (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  icon TEXT NOT NULL,
  severity TEXT NOT NULL CHECK (severity IN ('info','warning','critical')),
  rule_id TEXT NOT NULL,
  context JSONB NOT NULL DEFAULT '{}',
  generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_daily_tip_date ON daily_energy_tip(date DESC);

ALTER TABLE daily_energy_tip ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS daily_tip_user_select ON daily_energy_tip;
CREATE POLICY daily_tip_user_select
  ON daily_energy_tip FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR private.is_admin());

-- 2. energy_tips_realtime : pushes spontanés (live spike + agent)
CREATE TABLE IF NOT EXISTS energy_tips_realtime (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  icon TEXT NOT NULL,
  severity TEXT NOT NULL CHECK (severity IN ('info','warning','critical')),
  source TEXT NOT NULL CHECK (source IN ('live_spike','agent')),
  rule_id TEXT,
  acknowledged BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_realtime_tip_user_created
  ON energy_tips_realtime(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_realtime_tip_unack
  ON energy_tips_realtime(user_id, created_at DESC)
  WHERE acknowledged = false;

ALTER TABLE energy_tips_realtime ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS realtime_tip_user_select ON energy_tips_realtime;
CREATE POLICY realtime_tip_user_select
  ON energy_tips_realtime FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR private.is_admin());

DROP POLICY IF EXISTS realtime_tip_user_update ON energy_tips_realtime;
CREATE POLICY realtime_tip_user_update
  ON energy_tips_realtime FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Activation Realtime broadcast sur energy_tips_realtime uniquement
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'energy_tips_realtime'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE energy_tips_realtime;
  END IF;
END $$;
