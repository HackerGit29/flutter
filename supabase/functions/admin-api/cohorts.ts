import { HttpError, jsonResponse } from "./http.ts";
import { type AdminContext, createAdminClient } from "./auth.ts";

/** GET /v1/kpi/cohorts?months=12 */
export async function handleCohorts(
  url: URL,
  _ctx: AdminContext,
): Promise<Response> {
  const months = Number(url.searchParams.get("months") ?? "12");
  if (!Number.isInteger(months) || months < 1 || months > 36) {
    throw new HttpError(
      "validation_error",
      "months doit être compris entre 1 et 36",
    );
  }
  const admin = createAdminClient();
  const { data, error } = await admin.rpc("admin_kpi_cohorts", {
    p_months: months,
  });
  if (error) {
    console.error("admin_kpi_cohorts error:", error);
    throw new HttpError(
      "internal_error",
      "Calcul des cohortes impossible",
      500,
    );
  }
  return jsonResponse({ data: data ?? [] });
}
