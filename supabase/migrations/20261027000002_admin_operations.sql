-- Backoffice : opérations admin, batch geo et exports CSV immédiats.

ALTER TYPE admin_action_type ADD VALUE IF NOT EXISTS 'create_zone';
ALTER TYPE admin_action_type ADD VALUE IF NOT EXISTS 'update_zone';
ALTER TYPE admin_action_type ADD VALUE IF NOT EXISTS 'delete_zone';
ALTER TYPE admin_action_type ADD VALUE IF NOT EXISTS 'bulk_geo';
ALTER TYPE admin_action_type ADD VALUE IF NOT EXISTS 'retry_command';
ALTER TYPE admin_action_type ADD VALUE IF NOT EXISTS 'export_user_data';
ALTER TYPE admin_action_type ADD VALUE IF NOT EXISTS 'create_export';
ALTER TYPE target_type ADD VALUE IF NOT EXISTS 'coverage_zone';
ALTER TYPE target_type ADD VALUE IF NOT EXISTS 'device_command';

ALTER TABLE agent_audit_logs DROP CONSTRAINT IF EXISTS agent_audit_logs_status_check;
ALTER TABLE agent_audit_logs ADD CONSTRAINT agent_audit_logs_status_check
  CHECK (status IN ('allowed', 'blocked', 'failed', 'success', 'pending'));

CREATE INDEX IF NOT EXISTS idx_device_commands_created_status
  ON device_commands(created_at DESC, status);
CREATE INDEX IF NOT EXISTS idx_sync_logs_timestamp_status
  ON sync_logs(timestamp DESC, status);

-- Prevent duplicate concurrent retries while allowing a later retry after a terminal state.
CREATE UNIQUE INDEX IF NOT EXISTS idx_device_commands_active_retry_reason
  ON device_commands(reason)
  WHERE reason LIKE 'retry:%'
    AND status IN ('pending', 'processing', 'sent');

CREATE OR REPLACE FUNCTION public.admin_update_boxes_geo_bulk(p_items JSONB)
RETURNS TABLE(box_id UUID, latitude DOUBLE PRECISION, longitude DOUBLE PRECISION, geo_precision TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  item_count INT;
  updated_count INT;
BEGIN
  IF COALESCE(auth.jwt() ->> 'role', '') <> 'service_role'
     AND NOT private.is_admin() THEN
    RAISE EXCEPTION 'admin_update_boxes_geo_bulk: accès réservé aux administrateurs'
      USING ERRCODE = '42501';
  END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' THEN
    RAISE EXCEPTION 'items doit être un tableau';
  END IF;
  item_count := jsonb_array_length(p_items);
  IF item_count < 1 OR item_count > 200 THEN
    RAISE EXCEPTION 'items doit contenir entre 1 et 200 éléments';
  END IF;
  IF (SELECT COUNT(DISTINCT (x->>'box_id')) FROM jsonb_array_elements(p_items) x) <> item_count THEN
    RAISE EXCEPTION 'box_id dupliqué';
  END IF;
  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_items) x
    WHERE x->>'box_id' IS NULL
       OR x->>'latitude' IS NULL       OR x->>'longitude' IS NULL
       OR x->>'geo_precision' IS NULL
       OR (x->>'latitude')::DOUBLE PRECISION NOT BETWEEN -90 AND 90
       OR (x->>'longitude')::DOUBLE PRECISION NOT BETWEEN -180 AND 180
       OR x->>'geo_precision' NOT IN ('exact', 'approx', 'city', 'manual')
  ) THEN
    RAISE EXCEPTION 'coordonnées ou précision invalides';
  END IF;

  RETURN QUERY
  UPDATE boxes b SET
    latitude = i.latitude,
    longitude = i.longitude,
    geo_precision = i.geo_precision
  FROM jsonb_to_recordset(p_items) AS i(
    box_id UUID,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    geo_precision TEXT
  )
  WHERE b.id = i.box_id
  RETURNING b.id, b.latitude, b.longitude, b.geo_precision;

  GET DIAGNOSTICS updated_count = ROW_COUNT;
  IF updated_count <> item_count THEN
    RAISE EXCEPTION 'un ou plusieurs boîtiers sont introuvables';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_update_boxes_geo_bulk(JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_update_boxes_geo_bulk(JSONB) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_iot_health()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_now TIMESTAMPTZ := NOW();
  v_total BIGINT;
  v_online BIGINT;
  v_stale BIGINT;
  v_commands BIGINT;
  v_acked BIGINT;
  v_p50 DOUBLE PRECISION;
  v_p95 DOUBLE PRECISION;
  v_top_errors JSONB;
  v_firmware JSONB;
BEGIN
  IF COALESCE(auth.jwt() ->> 'role', '') <> 'service_role'
     AND NOT private.is_admin() THEN
    RAISE EXCEPTION 'admin_iot_health: accès réservé aux administrateurs'
      USING ERRCODE = '42501';
  END IF;

  SELECT COUNT(*),
         COUNT(*) FILTER (WHERE status = 'active' AND last_sync >= v_now - INTERVAL '5 minutes'),
         COUNT(*) FILTER (WHERE last_sync IS NULL OR last_sync < v_now - INTERVAL '24 hours')
    INTO v_total, v_online, v_stale
    FROM boxes;

  SELECT COUNT(*), COUNT(*) FILTER (WHERE status = 'acknowledged')
    INTO v_commands, v_acked
    FROM device_commands
   WHERE created_at >= v_now - INTERVAL '24 hours';

  -- Compute latency percentiles directly in SQL; raw command events are not sent to the Edge Function.
  SELECT percentile_cont(0.5) WITHIN GROUP (
    ORDER BY EXTRACT(EPOCH FROM (acknowledged_at - created_at)) * 1000
  ), percentile_cont(0.95) WITHIN GROUP (
    ORDER BY EXTRACT(EPOCH FROM (acknowledged_at - created_at)) * 1000
  ) INTO v_p50, v_p95
    FROM device_commands
   WHERE created_at >= v_now - INTERVAL '24 hours'
     AND status = 'acknowledged'
     AND acknowledged_at >= created_at;

  SELECT COALESCE(JSONB_AGG(ROW_TO_JSON(t)), '[]'::JSONB) INTO v_top_errors
  FROM (
    SELECT b.id AS box_id, b.uid_hardware,
           COUNT(*) FILTER (WHERE d.status IN ('failed', 'timeout', 'rejected'))::INT AS failed,
           COUNT(*)::INT AS total
      FROM device_commands d
      JOIN boxes b ON b.id = d.box_id
     WHERE d.created_at >= v_now - INTERVAL '24 hours'
     GROUP BY b.id, b.uid_hardware
    HAVING COUNT(*) FILTER (WHERE d.status IN ('failed', 'timeout', 'rejected')) > 0
     ORDER BY COUNT(*) FILTER (WHERE d.status IN ('failed', 'timeout', 'rejected')) DESC
     LIMIT 10
  ) t;

  SELECT COALESCE(JSONB_AGG(JSONB_BUILD_OBJECT('version', version, 'count', count)), '[]'::JSONB)
    INTO v_firmware
    FROM (
      SELECT COALESCE(firmware_version, 'unknown') AS version, COUNT(*)::INT AS count
        FROM boxes GROUP BY 1 ORDER BY 1
    ) f;

  RETURN JSONB_BUILD_OBJECT(
    'total_boxes', v_total,
    'online_boxes', v_online,
    'offline_boxes', v_total - v_online,
    'stale_boxes', v_stale,
    'commands_24h', v_commands,
    'ack_rate_24h', CASE WHEN v_commands = 0 THEN 0 ELSE v_acked::DOUBLE PRECISION / v_commands END,
    'latency_p50_ms', v_p50,
    'latency_p95_ms', v_p95,
    'top_errored_boxes', v_top_errors,
    'firmware_distribution', v_firmware
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_iot_health() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_iot_health() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_agent_analytics(p_from TIMESTAMPTZ, p_to TIMESTAMPTZ)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_messages JSONB;
  v_tool_calls JSONB;
  v_tools JSONB;
  v_blocked BIGINT;
  v_pending BIGINT;
BEGIN
  IF COALESCE(auth.jwt() ->> 'role', '') <> 'service_role'
     AND NOT private.is_admin() THEN
    RAISE EXCEPTION 'admin_agent_analytics: accès réservé aux administrateurs'
      USING ERRCODE = '42501';
  END IF;
  IF p_from IS NULL OR p_to IS NULL OR p_from > p_to OR p_to - p_from > INTERVAL '366 days' THEN
    RAISE EXCEPTION 'période invalide (366 jours maximum)';
  END IF;

  SELECT COALESCE(JSONB_AGG(JSONB_BUILD_OBJECT('date', day, 'value', value) ORDER BY day), '[]'::JSONB)
    INTO v_messages
    FROM (
      SELECT created_at::DATE::TEXT AS day, COUNT(*)::INT AS value
        FROM analytics_events
       WHERE event = 'chat_message' AND created_at >= p_from AND created_at <= p_to
       GROUP BY created_at::DATE
    ) m;

  SELECT COALESCE(JSONB_AGG(JSONB_BUILD_OBJECT('date', day, 'value', value) ORDER BY day), '[]'::JSONB)
    INTO v_tool_calls
    FROM (
      SELECT created_at::DATE::TEXT AS day, COUNT(*)::INT AS value
        FROM agent_audit_logs
       WHERE action IN ('turn_on_appliance', 'turn_off_appliance')
         AND created_at >= p_from AND created_at <= p_to
       GROUP BY created_at::DATE
    ) d;

  SELECT COALESCE(JSONB_AGG(JSONB_BUILD_OBJECT(
    'tool_name', action,
    'calls_count', calls_count,
    'confirmation_rate', confirmation_rate,
    'success_rate', success_rate,
    'blocked_by_policy', blocked_by_policy
  ) ORDER BY action), '[]'::JSONB)
    INTO v_tools
    FROM (
      SELECT action,
             COUNT(*)::INT AS calls_count,
             (COUNT(*) FILTER (WHERE status = 'pending')::DOUBLE PRECISION / COUNT(*)) AS confirmation_rate,
             (COUNT(*) FILTER (WHERE status IN ('allowed', 'success'))::DOUBLE PRECISION / COUNT(*)) AS success_rate,
             COUNT(*) FILTER (WHERE status = 'blocked')::INT AS blocked_by_policy
        FROM agent_audit_logs
       WHERE action IN ('turn_on_appliance', 'turn_off_appliance')
         AND created_at >= p_from AND created_at <= p_to
       GROUP BY action
    ) t;

  SELECT COUNT(*) FILTER (WHERE status = 'blocked'),
         COUNT(*) FILTER (WHERE status = 'pending')
    INTO v_blocked, v_pending
    FROM agent_audit_logs
   WHERE created_at >= p_from AND created_at <= p_to;

  RETURN JSONB_BUILD_OBJECT(
    'messages_by_day', v_messages,
    'tool_calls_by_day', v_tool_calls,
    'tools', v_tools,
    'tool_pending_confirmed', NULL,
    'tool_pending_canceled', NULL,
    'policy_blocked', v_blocked,
    'confirmation_events_tracked', FALSE,
    'pending_tool_actions_observed', v_pending
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_agent_analytics(TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_agent_analytics(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_kpi_cohorts(p_months INT DEFAULT 12)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_result JSONB;
BEGIN
  IF COALESCE(auth.jwt() ->> 'role', '') <> 'service_role'
     AND NOT private.is_admin() THEN
    RAISE EXCEPTION 'admin_kpi_cohorts: accès réservé aux administrateurs'
      USING ERRCODE = '42501';
  END IF;
  IF p_months IS NULL OR p_months < 1 OR p_months > 36 THEN
    RAISE EXCEPTION 'p_months doit être compris entre 1 et 36';
  END IF;

  WITH month_bounds AS (
    SELECT DATE_TRUNC('month', CURRENT_DATE)::DATE AS current_month,
           (DATE_TRUNC('month', CURRENT_DATE) - ((p_months - 1) * INTERVAL '1 month'))::DATE AS first_month
  ), cohort_sizes AS (
    SELECT DATE_TRUNC('month', u.created_at)::DATE AS cohort_month,
           COUNT(*)::INT AS cohort_size
      FROM users u CROSS JOIN month_bounds b
     WHERE u.created_at >= b.first_month
       AND u.created_at < b.current_month + INTERVAL '1 month'
     GROUP BY 1
  ), retention_rows AS (
    SELECT c.cohort_month, c.cohort_size,
           JSONB_AGG(
             CASE
               WHEN c.cohort_month + (offsets.month_offset * INTERVAL '1 month') > b.current_month
                 THEN 'null'::JSONB
               ELSE TO_JSONB(CASE WHEN c.cohort_size = 0 THEN 0::NUMERIC ELSE
                 ROUND((COUNT(DISTINCT e.user_id)::NUMERIC / c.cohort_size), 4)
               END)
             END ORDER BY offsets.month_offset
           ) AS retention
      FROM cohort_sizes c CROSS JOIN month_bounds b
      CROSS JOIN GENERATE_SERIES(0, 11) AS offsets(month_offset)
      LEFT JOIN users cohort_users
        ON cohort_users.created_at >= c.cohort_month
       AND cohort_users.created_at < c.cohort_month + INTERVAL '1 month'
      LEFT JOIN analytics_events e
        ON e.user_id = cohort_users.id
       AND e.event = 'app_open'
       AND e.created_at >= c.cohort_month + (offsets.month_offset * INTERVAL '1 month')
       AND e.created_at < c.cohort_month + ((offsets.month_offset + 1) * INTERVAL '1 month')
     GROUP BY c.cohort_month, c.cohort_size, b.current_month
  )
  SELECT COALESCE(JSONB_AGG(JSONB_BUILD_OBJECT(
    'cohort', TO_CHAR(cohort_month, 'YYYY-MM'),
    'size', cohort_size,
    'retention', retention
  ) ORDER BY cohort_month), '[]'::JSONB)
    INTO v_result FROM retention_rows;
  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_kpi_cohorts(INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_kpi_cohorts(INT) TO authenticated, service_role;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('admin-exports', 'admin-exports', false, 52428800, ARRAY['text/csv'])
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;
