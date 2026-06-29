-- Migration: Energy rollup — single kwh column + cumulative snapshot
-- Replace total_day/week/month/year with kwh (delta journalier)
-- Refactor RPC to SUM(kwh) over date range

ALTER TABLE energy_data
  ADD COLUMN IF NOT EXISTS kwh DOUBLE PRECISION DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cumulative_kwh DOUBLE PRECISION;

UPDATE energy_data SET kwh = total_day WHERE kwh = 0;

ALTER TABLE energy_data
  DROP COLUMN IF EXISTS total_week,
  DROP COLUMN IF EXISTS total_month,
  DROP COLUMN IF EXISTS total_year;

CREATE INDEX IF NOT EXISTS idx_energy_data_kwh
  ON energy_data(kwh);

DROP FUNCTION IF EXISTS sum_total_consumption(UUID, TEXT);

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
    'total_kwh', COALESCE(SUM(ed.kwh), 0),
    'by_appliance', COALESCE(JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'appliance_id', ed.appliance_id,
        'name', a.name,
        'kwh', SUM(ed.kwh)
      ) ORDER BY SUM(ed.kwh) DESC
    ) FILTER (WHERE ed.appliance_id IS NOT NULL), '[]'::JSONB)
  ) INTO result
  FROM appliances a
  LEFT JOIN energy_data ed
    ON ed.appliance_id = a.id
    AND ed.date >= start_date
  WHERE a.user_id = requester_id
  GROUP BY a.id, a.name;

  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION sum_total_consumption(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION sum_total_consumption(UUID, TEXT) TO authenticated;
