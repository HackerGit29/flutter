-- Migration: Admin KPI RPCs — agrégats pour le backoffice web
-- Date: 2026-10-26
-- Ref: docs/cahier-des-charges-admin-dashboard.md §5.3.1 / §5.3.2
--
-- Les agrégats tournent en SQL (SECURITY DEFINER) pour éviter de transporter
-- des dizaines de milliers de lignes dans l'Edge Function.
-- Garde-fou : service_role (Edge Function admin-api) OU appelant admin (RLS).

-- ============================================================
-- 1. admin_action_type : valeurs manquantes pour le backoffice
--    (INSERT interdit dans le même bloc transactionnel que l'ALTER,
--     on ne fait qu'étendre l'enum ici)
-- ============================================================
ALTER TYPE admin_action_type ADD VALUE IF NOT EXISTS 'create_box';
ALTER TYPE admin_action_type ADD VALUE IF NOT EXISTS 'update_box';
ALTER TYPE admin_action_type ADD VALUE IF NOT EXISTS 'update_user';

-- ============================================================
-- 2. admin_kpi_summary() : snapshot décisionnel
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_kpi_summary()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total_users          INT;
  v_new_users_30d        INT;
  v_active_users_30d     INT;
  v_vip_subscribers      INT;
  v_churned_30d          INT;
  v_sub_base             INT;
  v_total_boxes          INT;
  v_online_boxes         INT;
  v_total_kwh_30d        DOUBLE PRECISION;
  v_agent_messages_30d   INT;
  v_cmd_total_30d        INT;
  v_cmd_ack_30d          INT;
  v_device_success_rate  DOUBLE PRECISION;
BEGIN
  -- Garde d'accès : service_role (via JWT claim) ou admin authentifié
  IF COALESCE(auth.jwt() ->> 'role', '') <> 'service_role'
     AND NOT private.is_admin() THEN
    RAISE EXCEPTION 'admin_kpi_summary: accès réservé aux administrateurs'
      USING ERRCODE = '42501';
  END IF;

  SELECT COUNT(*) INTO v_total_users FROM users;

  SELECT COUNT(*) INTO v_new_users_30d
  FROM users WHERE created_at >= NOW() - INTERVAL '30 days';

  -- Actif = a produit un événement produit ou une synchro boîtier sur 30 j
  SELECT COUNT(*) INTO v_active_users_30d FROM (
    SELECT user_id FROM analytics_events
      WHERE created_at >= NOW() - INTERVAL '30 days' AND user_id IS NOT NULL
    UNION
    SELECT user_id FROM sync_logs
      WHERE timestamp >= NOW() - INTERVAL '30 days'
  ) t;

  SELECT COUNT(*) INTO v_vip_subscribers
  FROM subscriptions
  WHERE type = 'vip' AND is_active
    AND (end_date IS NULL OR end_date > NOW());

  -- Churn 30 j : abonnements terminés sur la période / base abonnés âgés de 30 j
  SELECT COUNT(*) INTO v_churned_30d
  FROM subscriptions
  WHERE end_date IS NOT NULL
    AND end_date >= NOW() - INTERVAL '30 days'
    AND end_date <= NOW();

  SELECT COUNT(*) INTO v_sub_base
  FROM subscriptions
  WHERE created_at <= NOW() - INTERVAL '30 days';

  SELECT COUNT(*) INTO v_total_boxes FROM boxes;

  SELECT COUNT(*) INTO v_online_boxes
  FROM boxes
  WHERE status = 'active' AND last_sync >= NOW() - INTERVAL '5 minutes';

  SELECT COALESCE(SUM(kwh), 0) INTO v_total_kwh_30d
  FROM energy_data
  WHERE date >= CURRENT_DATE - 30;

  SELECT COUNT(*) INTO v_agent_messages_30d
  FROM analytics_events
  WHERE event = 'chat_message'
    AND created_at >= NOW() - INTERVAL '30 days';

  -- Taux de succès des commandes IoT : ACK / (total hors pending)
  SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE status = 'acknowledged')
  INTO v_cmd_total_30d, v_cmd_ack_30d
  FROM device_commands
  WHERE created_at >= NOW() - INTERVAL '30 days'
    AND status <> 'pending';

  v_device_success_rate := CASE
    WHEN v_cmd_total_30d = 0 THEN NULL
    ELSE ROUND((v_cmd_ack_30d::DOUBLE PRECISION / v_cmd_total_30d)::NUMERIC, 4)::DOUBLE PRECISION
  END;

  RETURN JSONB_BUILD_OBJECT(
    'period', 'month',
    'total_users', v_total_users,
    'active_users_30d', v_active_users_30d,
    'new_users_30d', v_new_users_30d,
    'churn_rate', CASE
      WHEN v_sub_base = 0 THEN 0
      ELSE ROUND((v_churned_30d::DOUBLE PRECISION / v_sub_base)::NUMERIC, 4)::DOUBLE PRECISION
    END,
    'vip_subscribers', v_vip_subscribers,
    'total_boxes', v_total_boxes,
    'online_boxes', v_online_boxes,
    'total_kwh_30d', ROUND(v_total_kwh_30d::NUMERIC, 3)::DOUBLE PRECISION,
    'agent_messages_30d', v_agent_messages_30d,
    'device_success_rate', v_device_success_rate
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_kpi_summary() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_kpi_summary() TO authenticated, service_role;

-- ============================================================
-- 3. admin_kpi_timeseries(metric, from, to, granularity)
--    Série temporelle pour les graphiques du backoffice.
--    metric : users | boxes | kwh | agent_messages | device_commands
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_kpi_timeseries(
  p_metric TEXT,
  p_from DATE DEFAULT CURRENT_DATE - 90,
  p_to DATE DEFAULT CURRENT_DATE,
  p_granularity TEXT DEFAULT 'day'
)
RETURNS TABLE (bucket DATE, value NUMERIC)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF COALESCE(auth.jwt() ->> 'role', '') <> 'service_role'
     AND NOT private.is_admin() THEN
    RAISE EXCEPTION 'admin_kpi_timeseries: accès réservé aux administrateurs'
      USING ERRCODE = '42501';
  END IF;

  IF p_granularity NOT IN ('day', 'week', 'month') THEN
    RAISE EXCEPTION 'granularity invalide: % (day|week|month)', p_granularity;
  END IF;

  IF p_from > p_to THEN
    RAISE EXCEPTION 'p_from (%) > p_to (%)', p_from, p_to;
  END IF;

  IF p_metric = 'users' THEN
    RETURN QUERY
      SELECT DATE_TRUNC(p_granularity, u.created_at)::DATE,
             COUNT(*)::NUMERIC
      FROM users u
      WHERE u.created_at::DATE BETWEEN p_from AND p_to
      GROUP BY 1
      ORDER BY 1;

  ELSIF p_metric = 'boxes' THEN
    RETURN QUERY
      SELECT DATE_TRUNC(p_granularity, b.created_at)::DATE,
             COUNT(*)::NUMERIC
      FROM boxes b
      WHERE b.created_at::DATE BETWEEN p_from AND p_to
      GROUP BY 1
      ORDER BY 1;

  ELSIF p_metric = 'kwh' THEN
    RETURN QUERY
      SELECT DATE_TRUNC(p_granularity, e.date)::DATE,
             COALESCE(SUM(e.kwh), 0)::NUMERIC
      FROM energy_data e
      WHERE e.date BETWEEN p_from AND p_to
      GROUP BY 1
      ORDER BY 1;

  ELSIF p_metric = 'agent_messages' THEN
    RETURN QUERY
      SELECT DATE_TRUNC(p_granularity, a.created_at)::DATE,
             COUNT(*)::NUMERIC
      FROM analytics_events a
      WHERE a.event = 'chat_message'
        AND a.created_at::DATE BETWEEN p_from AND p_to
      GROUP BY 1
      ORDER BY 1;

  ELSIF p_metric = 'device_commands' THEN
    RETURN QUERY
      SELECT DATE_TRUNC(p_granularity, d.created_at)::DATE,
             COUNT(*)::NUMERIC
      FROM device_commands d
      WHERE d.created_at::DATE BETWEEN p_from AND p_to
      GROUP BY 1
      ORDER BY 1;

  ELSE
    RAISE EXCEPTION 'metric invalide: % (users|boxes|kwh|agent_messages|device_commands)',
      p_metric;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_kpi_timeseries(TEXT, DATE, DATE, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_kpi_timeseries(TEXT, DATE, DATE, TEXT) TO authenticated, service_role;
