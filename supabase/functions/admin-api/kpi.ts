// Edge Function admin-api — routes KPI décisionnels
// Ref: docs/cahier-des-charges-admin-dashboard.md §5.3.1 / §5.3.2
//
// GET /v1/kpi/summary     → snapshot (RPC admin_kpi_summary)
// GET /v1/kpi/timeseries  → série temporelle (RPC admin_kpi_timeseries)
//
// Les agrégats tournent en SQL (migration 20261026000003) : l'Edge Function
// ne transporte jamais les lignes brutes.

import { HttpError, jsonResponse } from "./http.ts";
import { createAdminClient } from "./auth.ts";

const VALID_METRICS = new Set([
  "users",
  "boxes",
  "kwh",
  "agent_messages",
  "device_commands",
]);

const VALID_PERIODS = new Set(["day", "week", "month", "quarter"]);
const VALID_GRANULARITIES = new Set(["day", "week", "month"]);

const ISO_DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

// Prix VIP mensuel en euros — TODO: déplacer en config/table quand le billing
// sera branché. Sert au calcul du MRR affiché dans le backoffice.
const VIP_MONTHLY_PRICE_EUR = Number(
  Deno.env.get("VIP_MONTHLY_PRICE_EUR") ?? "0",
);

/** GET /v1/kpi/summary?period=month */
export async function handleKpiSummary(url: URL): Promise<Response> {
  const period = url.searchParams.get("period") ?? "month";
  if (!VALID_PERIODS.has(period)) {
    throw new HttpError(
      "validation_error",
      `period invalide: ${period} (day|week|month|quarter)`,
    );
  }

  const admin = createAdminClient();
  const { data, error } = await admin.rpc("admin_kpi_summary");

  if (error) {
    console.error("admin_kpi_summary error:", error);
    throw new HttpError("internal_error", "Calcul des KPI impossible", 500);
  }

  const summary = data as Record<string, unknown>;

  return jsonResponse({
    ...summary,
    period,
    // MRR VIP = abonnés VIP × prix mensuel (config)
    mrr_vip: (summary.vip_subscribers as number ?? 0) * VIP_MONTHLY_PRICE_EUR,
  });
}

/** GET /v1/kpi/timeseries?metric=kwh&from=2026-01-01&to=2026-10-26&granularity=day */
export async function handleKpiTimeseries(url: URL): Promise<Response> {
  const metric = url.searchParams.get("metric");
  if (!metric || !VALID_METRICS.has(metric)) {
    throw new HttpError(
      "validation_error",
      `metric invalide: ${metric} (users|boxes|kwh|agent_messages|device_commands)`,
    );
  }

  const granularity = url.searchParams.get("granularity") ?? "day";
  if (!VALID_GRANULARITIES.has(granularity)) {
    throw new HttpError(
      "validation_error",
      `granularity invalide: ${granularity} (day|week|month)`,
    );
  }

  const to = url.searchParams.get("to") ?? new Date().toISOString().slice(0, 10);
  const defaultFrom = new Date(Date.now() - 90 * 86400_000)
    .toISOString().slice(0, 10);
  const from = url.searchParams.get("from") ?? defaultFrom;

  if (!ISO_DATE_RE.test(from) || !ISO_DATE_RE.test(to)) {
    throw new HttpError("validation_error", "from/to doivent être au format YYYY-MM-DD");
  }

  const admin = createAdminClient();
  const { data, error } = await admin.rpc("admin_kpi_timeseries", {
    p_metric: metric,
    p_from: from,
    p_to: to,
    p_granularity: granularity,
  });

  if (error) {
    console.error("admin_kpi_timeseries error:", error);
    throw new HttpError("internal_error", "Calcul de la série impossible", 500);
  }

  return jsonResponse({
    metric,
    granularity,
    from,
    to,
    points: data ?? [],
  });
}
