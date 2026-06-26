-- Migration: realtime_power + RPC sum_total_consumption
-- Date: 2026-06-26
-- Spec: docs/superpowers/specs/2026-06-25-aricie-agent-rag-design.md

-- 1. realtime_power : dernière valeur de puissance par appliance (UPSERT)
CREATE TABLE IF NOT EXISTS realtime_power (
  appliance_id UUID PRIMARY KEY REFERENCES appliances(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  box_id UUID NOT NULL,
  power_kwh NUMERIC(12,6) NOT NULL,
  instant_power_w NUMERIC(10,2),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE realtime_power ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS realtime_power_user_select ON realtime_power;
CREATE POLICY realtime_power_user_select
  ON realtime_power FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR private.is_admin());

CREATE INDEX IF NOT EXISTS idx_realtime_power_user
  ON realtime_power(user_id);

CREATE INDEX IF NOT EXISTS idx_realtime_power_updated
  ON realtime_power(updated_at DESC);

-- Activation Supabase Realtime broadcast (écoute per-user côté Flutter)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'realtime_power'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE realtime_power;
  END IF;
END $$;

-- 2. RPC SECURITY DEFINER : agrégation multi-appareils scope par user_id
--    Le code appelant NE PEUT PAS skipper le WHERE user_id = requester_id.
CREATE OR REPLACE FUNCTION sum_total_consumption(
  requester_id UUID,
  period TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  start_date DATE;
  result JSONB;
BEGIN
  start_date := CASE period
    WHEN 'day'   THEN CURRENT_DATE
    WHEN 'week'  THEN DATE_TRUNC('week', CURRENT_DATE)::DATE
    WHEN 'month' THEN DATE_TRUNC('month', CURRENT_DATE)::DATE
    WHEN 'year'  THEN DATE_TRUNC('year', CURRENT_DATE)::DATE
    ELSE CURRENT_DATE
  END;

  SELECT JSONB_BUILD_OBJECT(
    'period', period,
    'total_kwh', COALESCE(SUM(ed.total_day), 0),
    'by_appliance', COALESCE(JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'appliance_id', ed.appliance_id,
        'name', a.name,
        'kwh', ed.total_day
      ) ORDER BY ed.total_day DESC
    ), '[]'::JSONB)
  ) INTO result
  FROM appliances a
  LEFT JOIN energy_data ed
    ON ed.appliance_id = a.id
    AND ed.date >= start_date
  WHERE a.user_id = requester_id;

  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION sum_total_consumption(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION sum_total_consumption(UUID, TEXT) TO authenticated;
