-- Migration: embeddings cleanup cron
-- Nettoie les embeddings orphelins (users supprimés) + embeddings > 90 jours
-- S'exécute toutes les nuits à 03:00 UTC

SELECT cron.schedule(
  'embeddings-cleanup',
  '0 3 * * *',
  $$SELECT net.http_post(
    url := current_setting('supabase.functions.embeddings-cleanup.url', true),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('supabase.functions.embeddings-cleanup.anon-key', true)
    ),
    body := '{}'::jsonb
  ) AS request_id;$$
);
