// Edge Function admin-api — routes Géo (carte de couverture + heatmap)
// Ref: docs/cahier-des-charges-admin-dashboard.md §5.3.4 / §5.3.5
//
// GET /v1/geo/coverage → clusters geohash + zones cibles (viewer+)
// GET /v1/geo/heatmap  → points pondérés pour le rendu heatmap (viewer+)
//
// Les agrégats tournent en SQL (migration 20261026000004) : géohash
// calculé côté base, jamais de lignes brutes transportées.

import { HttpError, jsonResponse } from "./http.ts";
import { createAdminClient, type AdminContext } from "./auth.ts";

const VALID_HEATMAP_METRICS = new Set([
  "boxes",
  "users",
  "kwh",
  "new_installations",
]);

const ISO_DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

/**
 * GET /v1/geo/coverage?bbox=minLng,minLat,maxLng,maxLat&precision=5&zone_id=…
 * bbox optionnelle (défaut : toutes les installations).
 * precision = longueur du geohash 3..8 (auto selon zoom côté front :
 * 4 en vue nationale → 6 en vue rue).
 */
export async function handleGeoCoverage(
  url: URL,
  _ctx: AdminContext,
): Promise<Response> {
  const precisionRaw = parseInt(url.searchParams.get("precision") ?? "5", 10);
  const precision = Number.isNaN(precisionRaw) ? 5 : precisionRaw;
  if (precision < 3 || precision > 8) {
    throw new HttpError("validation_error", `precision invalide: ${precision} (3..8)`);
  }

  let minLng: number | null = null;
  let minLat: number | null = null;
  let maxLng: number | null = null;
  let maxLat: number | null = null;

  const bbox = url.searchParams.get("bbox");
  if (bbox) {
    const parts = bbox.split(",").map((s) => Number(s.trim()));
    if (parts.length !== 4 || parts.some((n) => Number.isNaN(n))) {
      throw new HttpError(
        "validation_error",
        "bbox invalide (format minLng,minLat,maxLng,maxLat)",
      );
    }
    [minLng, minLat, maxLng, maxLat] = parts;
    if (minLng! > maxLng! || minLat! > maxLat!) {
      throw new HttpError("validation_error", "bbox inversée (min > max)");
    }
  }

  const admin = createAdminClient();

  const [clustersRes, zonesRes] = await Promise.all([
    admin.rpc("admin_geo_coverage", {
      p_min_lng: minLng,
      p_min_lat: minLat,
      p_max_lng: maxLng,
      p_max_lat: maxLat,
      p_precision: precision,
    }),
    admin.rpc("admin_geo_zone_stats"),
  ]);

  if (clustersRes.error) {
    console.error("admin_geo_coverage error:", clustersRes.error);
    throw new HttpError("internal_error", "Calcul de la couverture impossible", 500);
  }
  if (zonesRes.error) {
    console.error("admin_geo_zone_stats error:", zonesRes.error);
    throw new HttpError("internal_error", "Lecture des zones impossible", 500);
  }

  const clusters = (clustersRes.data ?? []) as any[];

  // Filtre éventuel sur une zone : on garde les clusters dont le centre
  // tombe dans la zone demandée (cercle centre/rayon).
  const zoneId = url.searchParams.get("zone_id");
  let visibleClusters = clusters;
  if (zoneId) {
    const zone = ((zonesRes.data ?? []) as any[]).find((z) => z.id === zoneId);
    if (!zone) {
      throw new HttpError("not_found", "Zone introuvable", 404);
    }
    const dLat = zone.radius_km / 111.32;
    const dLng = zone.radius_km / Math.max(111.32 * Math.cos((zone.center_lat * Math.PI) / 180), 0.01);
    visibleClusters = clusters.filter(
      (c) =>
        c.lat >= zone.center_lat - dLat && c.lat <= zone.center_lat + dLat &&
        c.lng >= zone.center_lng - dLng && c.lng <= zone.center_lng + dLng,
    );
  }

  return jsonResponse({
    precision,
    clusters: visibleClusters.map((c) => ({
      geohash: c.geohash,
      lat: c.lat,
      lng: c.lng,
      box_count: c.box_count,
      user_count: c.user_count,
      vip_count: c.vip_count,
      zone_id: zoneId ?? null,
    })),
    zones: (zonesRes.data ?? []).map((z: any) => ({
      id: z.id,
      name: z.name,
      center_lat: z.center_lat,
      center_lng: z.center_lng,
      radius_km: z.radius_km,
      target_clients: z.target_clients,
      is_active: z.is_active,
      current_clients: z.current_clients,
      progress: z.target_clients > 0
        ? Math.round((z.current_clients / z.target_clients) * 100) / 100
        : null,
    })),
  });
}

/**
 * GET /v1/geo/heatmap?metric=boxes|users|kwh|new_installations&from=&to=
 * Chaque point porte un poids (1 par boîtier, kwh agrégé, nb clients…).
 */
export async function handleGeoHeatmap(
  url: URL,
  _ctx: AdminContext,
): Promise<Response> {
  const metric = url.searchParams.get("metric") ?? "boxes";
  if (!VALID_HEATMAP_METRICS.has(metric)) {
    throw new HttpError(
      "validation_error",
      `metric invalide: ${metric} (boxes|users|kwh|new_installations)`,
    );
  }

  const to = url.searchParams.get("to") ?? new Date().toISOString().slice(0, 10);
  const defaultFrom = new Date(Date.now() - 30 * 86400_000)
    .toISOString().slice(0, 10);
  const from = url.searchParams.get("from") ?? defaultFrom;

  if (!ISO_DATE_RE.test(from) || !ISO_DATE_RE.test(to)) {
    throw new HttpError("validation_error", "from/to doivent être au format YYYY-MM-DD");
  }

  const admin = createAdminClient();
  const { data, error } = await admin.rpc("admin_geo_heatmap", {
    p_metric: metric,
    p_from: from,
    p_to: to,
  });

  if (error) {
    console.error("admin_geo_heatmap error:", error);
    throw new HttpError("internal_error", "Calcul de la heatmap impossible", 500);
  }

  return jsonResponse({
    metric,
    from,
    to,
    points: data ?? [],
  });
}
