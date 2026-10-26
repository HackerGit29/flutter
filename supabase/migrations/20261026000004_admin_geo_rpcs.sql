-- Migration: Admin geo RPCs — clusters de couverture + heatmap
-- Date: 2026-10-26
-- Ref: docs/cahier-des-charges-admin-dashboard.md §5.3.4 / §5.3.5
--
-- Alimente GET /v1/geo/coverage (clusters + zones) et
-- GET /v1/geo/heatmap (points pondérés) du backoffice.
-- Même garde d'accès que les KPI : service_role OU private.is_admin().

-- ============================================================
-- 1. geo_geohash() : encoding geohash standard (base32, échantillonnage
--    alterné lng/lat) — le clustering se fait par préfixe de geohash,
--    coût O(n) sur les seuls boîtiers géolocalisés.
-- ============================================================
CREATE OR REPLACE FUNCTION public.geo_geohash(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_precision INT DEFAULT 5
)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_alphabet TEXT := '0123456789bcdefghjkmnpqrstuvwxyz';
  v_min_lat DOUBLE PRECISION := -90.0;
  v_max_lat DOUBLE PRECISION := 90.0;
  v_min_lng DOUBLE PRECISION := -180.0;
  v_max_lng DOUBLE PRECISION := 180.0;
  v_mid DOUBLE PRECISION;
  v_ch INT := 0;
  v_bit INT := 0;
  v_even BOOLEAN := true;
  v_result TEXT := '';
BEGIN
  IF p_lat IS NULL OR p_lng IS NULL OR p_precision IS NULL OR p_precision < 1 THEN
    RETURN NULL;
  END IF;
  -- borne les valeurs d'entrée
  p_lat := GREATEST(LEAST(p_lat, 90.0), -90.0);
  p_lng := GREATEST(LEAST(p_lng, 180.0), -180.0);

  WHILE LENGTH(v_result) < LEAST(p_precision, 12) LOOP
    IF v_even THEN
      v_mid := (v_min_lng + v_max_lng) / 2;
      IF p_lng > v_mid THEN
        v_ch := (v_ch << 1) | 1; v_min_lng := v_mid;
      ELSE
        v_ch := v_ch << 1;       v_max_lng := v_mid;
      END IF;
    ELSE
      v_mid := (v_min_lat + v_max_lat) / 2;
      IF p_lat > v_mid THEN
        v_ch := (v_ch << 1) | 1; v_min_lat := v_mid;
      ELSE
        v_ch := v_ch << 1;       v_max_lat := v_mid;
      END IF;
    END IF;
    v_even := NOT v_even;
    v_bit := v_bit + 1;
    IF v_bit = 5 THEN
      v_result := v_result || SUBSTR(v_alphabet, v_ch + 1, 1);
      v_bit := 0;
      v_ch := 0;
    END IF;
  END LOOP;

  RETURN v_result;
END;
$$;

-- ============================================================
-- 2. admin_geo_coverage() : clusters de boîtiers par geohash
--    bbox optionnelle (bornes WGS84), precision = longueur de geohash
--    (3 ≈ ville, 5 ≈ quartier, 7 ≈ rue).
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_geo_coverage(
  p_min_lng DOUBLE PRECISION DEFAULT NULL,
  p_min_lat DOUBLE PRECISION DEFAULT NULL,
  p_max_lng DOUBLE PRECISION DEFAULT NULL,
  p_max_lat DOUBLE PRECISION DEFAULT NULL,
  p_precision INT DEFAULT 5
)
RETURNS TABLE (
  geohash TEXT,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  box_count BIGINT,
  user_count BIGINT,
  vip_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF COALESCE(auth.jwt() ->> 'role', '') <> 'service_role'
     AND NOT private.is_admin() THEN
    RAISE EXCEPTION 'admin_geo_coverage: accès réservé aux administrateurs'
      USING ERRCODE = '42501';
  END IF;
  IF p_precision IS NULL OR p_precision < 3 OR p_precision > 8 THEN
    RAISE EXCEPTION 'precision invalide: % (3..8)', p_precision;
  END IF;

  RETURN QUERY
  SELECT
    public.geo_geohash(b.latitude, b.longitude, p_precision) AS gh,
    ROUND(AVG(b.latitude)::NUMERIC, 6)::DOUBLE PRECISION,
    ROUND(AVG(b.longitude)::NUMERIC, 6)::DOUBLE PRECISION,
    COUNT(*)::BIGINT,
    COUNT(DISTINCT b.user_id)::BIGINT,
    COUNT(DISTINCT CASE
      WHEN s.is_active AND s.type = 'vip' THEN b.user_id
    END)::BIGINT
  FROM boxes b
  LEFT JOIN subscriptions s
    ON s.user_id = b.user_id AND s.is_active
  WHERE b.latitude IS NOT NULL
    AND b.longitude IS NOT NULL
    AND (p_min_lng IS NULL OR b.longitude >= p_min_lng)
    AND (p_min_lat IS NULL OR b.latitude >= p_min_lat)
    AND (p_max_lng IS NULL OR b.longitude <= p_max_lng)
    AND (p_max_lat IS NULL OR b.latitude <= p_max_lat)
  GROUP BY gh
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_geo_coverage(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_geo_coverage(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, INT) TO authenticated, service_role;

-- ============================================================
-- 3. admin_geo_zone_stats() : zones cibles + clients actuellement
--    installés dans le rayon (bornes lat/lng approchées, précision
--    suffisante pour un rayon de quelques km).
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_geo_zone_stats()
RETURNS TABLE (
  id UUID,
  name TEXT,
  center_lat DOUBLE PRECISION,
  center_lng DOUBLE PRECISION,
  radius_km DOUBLE PRECISION,
  target_clients INT,
  is_active BOOLEAN,
  current_clients BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF COALESCE(auth.jwt() ->> 'role', '') <> 'service_role'
     AND NOT private.is_admin() THEN
    RAISE EXCEPTION 'admin_geo_zone_stats: accès réservé aux administrateurs'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    cz.id,
    cz.name,
    cz.center_lat,
    cz.center_lng,
    cz.radius_km,
    cz.target_clients,
    cz.is_active,
    COUNT(DISTINCT b.user_id)::BIGINT
  FROM coverage_zones cz
  LEFT JOIN boxes b
    ON b.latitude IS NOT NULL
   AND b.longitude IS NOT NULL
   AND b.latitude BETWEEN cz.center_lat - (cz.radius_km / 111.32)
                      AND cz.center_lat + (cz.radius_km / 111.32)
   AND b.longitude BETWEEN
        cz.center_lng - (cz.radius_km / GREATEST(111.32 * COS(RADIANS(cz.center_lat)), 0.01))
    AND cz.center_lng + (cz.radius_km / GREATEST(111.32 * COS(RADIANS(cz.center_lat)), 0.01))
  GROUP BY cz.id
  ORDER BY cz.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_geo_zone_stats() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_geo_zone_stats() TO authenticated, service_role;

-- ============================================================
-- 4. admin_geo_heatmap() : points pondérés pour la heatmap
--    metric : boxes | users | kwh | new_installations
--    p_from/p_to ignorés sauf pour new_installations (et bornent kwh).
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_geo_heatmap(
  p_metric TEXT DEFAULT 'boxes',
  p_from DATE DEFAULT CURRENT_DATE - 30,
  p_to DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  weight DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF COALESCE(auth.jwt() ->> 'role', '') <> 'service_role'
     AND NOT private.is_admin() THEN
    RAISE EXCEPTION 'admin_geo_heatmap: accès réservé aux administrateurs'
      USING ERRCODE = '42501';
  END IF;

  IF p_metric = 'boxes' THEN
    -- densité d'installation : 1 point par boîtier
    RETURN QUERY
      SELECT b.latitude, b.longitude, 1.0
      FROM boxes b
      WHERE b.latitude IS NOT NULL AND b.longitude IS NOT NULL;

  ELSIF p_metric = 'users' THEN
    -- clients distincts par emplacement de boîtier
    RETURN QUERY
      SELECT b.latitude, b.longitude, COUNT(DISTINCT b.user_id)::DOUBLE PRECISION
      FROM boxes b
      WHERE b.latitude IS NOT NULL AND b.longitude IS NOT NULL
      GROUP BY b.latitude, b.longitude;

  ELSIF p_metric = 'kwh' THEN
    -- consommation agrégée par foyer géolocalisé (période from/to)
    RETURN QUERY
      SELECT b.latitude, b.longitude, COALESCE(SUM(ed.kwh), 0)::DOUBLE PRECISION
      FROM energy_data ed
      JOIN appliances a ON a.id = ed.appliance_id
      JOIN boxes b ON b.id = a.box_id
      WHERE b.latitude IS NOT NULL
        AND b.longitude IS NOT NULL
        AND ed.date BETWEEN p_from AND p_to
      GROUP BY b.latitude, b.longitude;

  ELSIF p_metric = 'new_installations' THEN
    -- boîtiers installés sur la période (installed_at, repli created_at)
    RETURN QUERY
      SELECT b.latitude, b.longitude, COUNT(*)::DOUBLE PRECISION
      FROM boxes b
      WHERE b.latitude IS NOT NULL
        AND b.longitude IS NOT NULL
        AND COALESCE(b.installed_at, b.created_at)::DATE BETWEEN p_from AND p_to
      GROUP BY b.latitude, b.longitude;

  ELSE
    RAISE EXCEPTION 'metric invalide: % (boxes|users|kwh|new_installations)',
      p_metric;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_geo_heatmap(TEXT, DATE, DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_geo_heatmap(TEXT, DATE, DATE) TO authenticated, service_role;
