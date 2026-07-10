-- Migration: energy aggregator daily cron
-- Planifie l'ETL realtime_power -> energy_data tous les jours à 23:55 UTC (juste
-- avant le changement de jour) pour capturer la conso du jour et alimenter la
-- « Tendance Hebdomadaire » de l'accueil.
--
-- Prérequis : extensions pg_cron + pg_net activées, fonction `energy-aggregator`
-- déployée (`supabase functions deploy energy-aggregator`).
--
-- ⚠️ PAS de paramètres de session à tirets :
--   current_setting('supabase.functions.energy-aggregator.url') NE MARCHE PAS —
--   « energy-aggregator » / « anon-key » contiennent des tirets, interdits dans
--   un nom de GUC (« Custom parameter names must be simple identifiers »). Même
--   défaut dans l'ancien cron tips-generator. On inscrit donc l'URL et la clé
--   anon directement dans la commande du job.
--
-- Avant d'appliquer sur un nouvel environnement : remplacer __ANON_KEY__ par la
-- clé « anon public » du projet (Dashboard > Project Settings > API). Cette clé
-- est publique (déjà embarquée dans l'app), mais on la laisse en placeholder ici
-- pour respecter la convention du repo (aucune clé versionnée) ; en prod elle
-- est déjà posée dans le job cron.

-- Idempotent : retire un éventuel job existant avant de (re)créer.
SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'energy-aggregator';

SELECT cron.schedule(
  'energy-aggregator',
  '55 23 * * *',
  $job$
  SELECT net.http_post(
    url := 'https://eevjozgobudwnbvjecnw.supabase.co/functions/v1/energy-aggregator',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer __ANON_KEY__'
    ),
    body := '{}'::jsonb
  ) AS request_id;
  $job$
);
