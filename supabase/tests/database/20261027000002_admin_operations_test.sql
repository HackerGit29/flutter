BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SELECT plan(8);

SELECT set_config('request.jwt.claims', '{"role":"service_role"}', true);

SELECT has_function('public', 'admin_update_boxes_geo_bulk', ARRAY['jsonb'], 'bulk geo RPC is installed');
SELECT has_function('public', 'admin_iot_health', 'IoT health RPC is installed');
SELECT has_function('public', 'admin_agent_analytics', ARRAY['timestamptz', 'timestamptz'], 'agent analytics RPC is installed');
SELECT has_function('public', 'admin_kpi_cohorts', ARRAY['integer'], 'cohort RPC is installed');
SELECT has_index('public', 'device_commands', 'idx_device_commands_active_retry_reason', 'active retry deduplication index is installed');
SELECT ok(
  (SELECT NOT public FROM storage.buckets WHERE id = 'admin-exports'),
  'admin export bucket is private'
);

SELECT throws_ok(
  $$SELECT * FROM public.admin_update_boxes_geo_bulk(NULL::jsonb)$$,
  'P0001',
  'items doit être un tableau',
  'bulk geo RPC rejects a NULL item list'
);

SELECT throws_ok(
  $$SELECT * FROM public.admin_update_boxes_geo_bulk('[]'::jsonb)$$,
  'P0001',
  'items doit contenir entre 1 et 200 éléments',
  'bulk geo RPC rejects an empty item list'
);

SELECT * FROM finish();
ROLLBACK;
