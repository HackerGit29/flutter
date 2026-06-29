-- Fix sum_total_consumption RPC: GROUP BY in SELECT INTO causes TOO_MANY_ROWS
-- when user has >1 appliance. Use scalar subqueries instead.

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
    'total_kwh', COALESCE((
      SELECT SUM(ed.kwh)
      FROM appliances a
      LEFT JOIN energy_data ed ON ed.appliance_id = a.id AND ed.date >= start_date
      WHERE a.user_id = requester_id
    ), 0),
    'by_appliance', COALESCE((
      SELECT JSONB_AGG(sub ORDER BY (sub->>'kwh')::numeric DESC)
      FROM (
        SELECT JSONB_BUILD_OBJECT(
          'appliance_id', a.id,
          'name', a.name,
          'kwh', COALESCE(SUM(ed.kwh), 0)
        ) AS sub
        FROM appliances a
        LEFT JOIN energy_data ed ON ed.appliance_id = a.id AND ed.date >= start_date
        WHERE a.user_id = requester_id
        GROUP BY a.id, a.name
      ) grouped
    ), '[]'::JSONB)
  ) INTO result;

  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION sum_total_consumption(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION sum_total_consumption(UUID, TEXT) TO authenticated;
