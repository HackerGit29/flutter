-- Migration: tips generator daily cron
-- Generates daily energy tips for all active subscribers at 05:00 UTC
-- Requires custom settings (set via Supabase Dashboard > Database > Session Parameters):
--   supabase.functions.tips-generator.url      = https://<project>.supabase.co/functions/v1/tips-generator
--   supabase.functions.tips-generator.anon-key = <anon-key>

SELECT cron.schedule(
  'tips-generator',
  '0 5 * * *',
  $$SELECT net.http_post(
    url := current_setting('supabase.functions.tips-generator.url', true),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('supabase.functions.tips-generator.anon-key', true)
    ),
    body := '{}'::jsonb
  ) AS request_id;$$
);
