-- =============================================================================
-- SEED DE DÉMONSTRATION — historique hebdomadaire (energy_data)
-- =============================================================================
-- But : remplir la « Tendance Hebdomadaire » de l'accueil IMMÉDIATEMENT, avant
-- que le cron `energy-aggregator` n'ait accumulé plusieurs jours réels.
--
-- ⚠️ Données NON réelles : `realtime_power` est un instantané (1 ligne/appareil),
-- l'historique passé n'a jamais été stocké. Ce script sème donc 7 jours
-- plausibles. À réserver à la démo / soutenance ; ne pas utiliser en prod.
--
-- Utilisation : Supabase > SQL Editor (rôle service_role/postgres).
--   1. Remplacer :uid ci-dessous par ton UUID utilisateur.
--   2. Exécuter. Idempotent (ON CONFLICT) : rejouable sans doublon.
-- Pour retirer le seed :  DELETE FROM energy_data WHERE user_id = '<UID>';
-- =============================================================================

WITH params AS (
  SELECT '00000000-0000-0000-0000-000000000000'::uuid AS uid  -- <-- REMPLACER
),
base AS (
  -- 1 ligne par appareil de l'utilisateur × 7 derniers jours (aujourd'hui inclus)
  SELECT
    a.user_id,
    a.id AS appliance_id,
    (CURRENT_DATE - g)::date AS d,
    round((0.6 + random() * 1.8)::numeric, 3) AS kwh   -- 0,6–2,4 kWh / jour
  FROM appliances a
  CROSS JOIN generate_series(0, 6) AS g
  WHERE a.user_id = (SELECT uid FROM params)
)
INSERT INTO energy_data
  (user_id, appliance_id, date, kwh, total_day, cumulative_kwh, week, month, year)
SELECT
  b.user_id,
  b.appliance_id,
  b.d,
  b.kwh,
  -- total_day = kwh : le graphe lit `kwh`, mais tips-generator/context.ts lit
  -- la colonne legacy `total_day` ; on garde les deux synchronisées.
  b.kwh AS total_day,
  -- cumulatif monotone croissant (cohérent pour le calcul de delta du cron)
  SUM(b.kwh) OVER (PARTITION BY b.appliance_id ORDER BY b.d) AS cumulative_kwh,
  EXTRACT(week  FROM b.d)::int,
  EXTRACT(month FROM b.d)::int,
  EXTRACT(year  FROM b.d)::int
FROM base b
ON CONFLICT (appliance_id, date) DO UPDATE SET
  kwh            = EXCLUDED.kwh,
  total_day      = EXCLUDED.total_day,
  cumulative_kwh = EXCLUDED.cumulative_kwh,
  week           = EXCLUDED.week,
  month          = EXCLUDED.month,
  year           = EXCLUDED.year;
